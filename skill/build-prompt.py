#!/usr/bin/env python3
"""
知识注入引擎 - 为 Agent Team Worker 注入项目知识和经验。
由 build-prompt.sh 调用，输出注入内容到 stdout。

用法: python3 build-prompt.py <project_root> <task_file> [--max-insights 10]
"""

import sys
import os
from datetime import datetime, timedelta


def parse_frontmatter(filepath):
    """从 markdown 文件解析 YAML frontmatter（简易实现，不依赖 pyyaml）"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except (FileNotFoundError, PermissionError):
        return {}

    if not content.startswith('---'):
        return {}

    end = content.find('---', 3)
    if end == -1:
        return {}

    fm = {}
    for line in content[3:end].strip().split('\n'):
        if ':' in line:
            key, _, value = line.partition(':')
            key = key.strip()
            value = value.strip()
            if value.startswith('[') and value.endswith(']'):
                value = [v.strip().strip('"').strip("'") for v in value[1:-1].split(',') if v.strip()]
            fm[key] = value
    return fm


def get_file_body(filepath):
    """获取 frontmatter 之后的正文内容"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except (FileNotFoundError, PermissionError):
        return ''

    if content.startswith('---'):
        end = content.find('---', 3)
        if end != -1:
            return content[end + 3:].strip()
    return content.strip()


def is_stale(filepath, days=30):
    """检查知识文件是否可能过时（updated 距今超过 days 天）"""
    fm = parse_frontmatter(filepath)
    updated = fm.get('updated', '')
    if not updated:
        return True
    try:
        update_date = datetime.strptime(str(updated), '%Y-%m-%d')
        return (datetime.now() - update_date) > timedelta(days=days)
    except ValueError:
        return True


def match_keywords(keywords, task_content):
    """大小写不敏感的子串匹配，任一 keyword 命中即返回 True"""
    task_lower = task_content.lower()
    for kw in keywords:
        if isinstance(kw, str) and kw.strip().lower() in task_lower:
            return True
    return False


def collect_insights(kb_dir, task_content, max_count):
    """收集匹配的经验条目"""
    insights = []
    insights_dir = os.path.join(kb_dir, 'insights')

    if not os.path.isdir(insights_dir):
        return insights

    for dirpath, _dirnames, filenames in os.walk(insights_dir):
        for fname in sorted(filenames):
            if not fname.endswith('.md'):
                continue

            fpath = os.path.join(dirpath, fname)
            fm = parse_frontmatter(fpath)

            try:
                confidence = float(fm.get('confidence', '0'))
            except (ValueError, TypeError):
                continue
            if confidence < 0.5:
                continue
            if '[dormant]' in str(fm.get('id', '')):
                continue

            keywords = fm.get('keywords', [])
            if isinstance(keywords, str):
                keywords = [keywords]

            if keywords and match_keywords(keywords, task_content):
                body = get_file_body(fpath)
                if body:
                    insights.append({
                        'id': fm.get('id', fname),
                        'confidence': confidence,
                        'body': body
                    })

    insights.sort(key=lambda x: x['confidence'], reverse=True)
    return insights[:max_count]


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 build-prompt.py <project_root> <task_file> [--max-insights 10]", file=sys.stderr)
        sys.exit(1)

    project_root = sys.argv[1]
    task_file = sys.argv[2]
    max_insights = 10

    if '--max-insights' in sys.argv:
        idx = sys.argv.index('--max-insights')
        if idx + 1 < len(sys.argv):
            max_insights = int(sys.argv[idx + 1])

    # 解析符号链接和相对路径，确保取到真实项目名
    project_name = os.path.basename(os.path.realpath(project_root))
    kb_base = os.path.expanduser('~/.claude/agent-kb')
    project_kb = os.path.join(kb_base, project_name)
    global_kb = os.path.join(kb_base, '_global')

    task_content = ''
    # task_file 可能是 "task-003" 这样的文件名，需拼接完整路径
    task_path = task_file
    if not os.path.isabs(task_file) and not os.path.isfile(task_file):
        task_path = os.path.join(project_root, '.team', 'tasks', task_file + '.md')
    if os.path.isfile(task_path):
        with open(task_path, 'r', encoding='utf-8') as f:
            task_content = f.read()

    output_parts = []

    # === Layer 5: 接口契约 ===
    contracts_file = os.path.join(project_root, '.team', 'contracts.md')
    if os.path.isfile(contracts_file):
        body = get_file_body(contracts_file)
        if body:
            output_parts.append('## 接口契约参考\n\n' + body)

    # === Layer 6a: 项目 overview ===
    # 排除规则：文件开头包含 "<!-- Agent" 的 overview 视为未填充模板，跳过注入
    overview_file = os.path.join(project_kb, 'overview.md')
    if os.path.isfile(overview_file):
        stale_tag = ' [可能过时，请以代码为准]' if is_stale(overview_file) else ''
        body = get_file_body(overview_file)
        if body and '<!-- Agent' not in body[:50]:
            output_parts.append(f'## 项目知识{stale_tag}\n\n' + body)
        elif body:
            print(f'[知识注入] 跳过 overview.md（未填充模板）', file=sys.stderr)

    # === Layer 6b: 匹配的 pitfalls ===
    # 排除规则：文件开头包含 "<!--" 的 pitfalls 视为未填充模板，跳过注入
    pitfalls_file = os.path.join(project_kb, 'pitfalls.md')
    if os.path.isfile(pitfalls_file):
        body = get_file_body(pitfalls_file)
        if body and '<!--' not in body[:20]:
            output_parts.append('## 踩坑记录（请注意避免）\n\n' + body)
        elif body:
            print(f'[知识注入] 跳过 pitfalls.md（未填充模板）', file=sys.stderr)

    # === Layer 6c: 匹配的 insights（项目级 + 全局）===
    all_insights = []
    all_insights.extend(collect_insights(project_kb, task_content, max_insights))
    remaining = max_insights - len(all_insights)
    if remaining > 0:
        all_insights.extend(collect_insights(global_kb, task_content, remaining))

    if all_insights:
        insight_text = '## 相关经验\n\n'
        for ins in all_insights:
            insight_text += f'### {ins["id"]} (confidence: {ins["confidence"]})\n\n{ins["body"]}\n\n'
        output_parts.append(insight_text)

    if output_parts:
        print('\n---\n\n# 知识注入（自动生成，仅供参考）\n')
        print('\n---\n'.join(output_parts))


if __name__ == '__main__':
    main()
