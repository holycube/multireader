import json
import urllib.request
import os
import datetime

script_dir = os.path.dirname(os.path.abspath(__file__))
taskmaster_dir = os.path.dirname(script_dir)
project_root = os.path.dirname(taskmaster_dir)
prd_path = os.path.join(taskmaster_dir, "docs", "prd.txt")


def _load_dotenv() -> None:
    env_path = os.path.join(project_root, ".env")
    if not os.path.isfile(env_path):
        return
    with open(env_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            os.environ.setdefault(key, value)


_load_dotenv()
api_key = os.environ.get("DEEPSEEK_API_KEY") or os.environ.get("OPENAI_API_KEY")
if not api_key:
    raise SystemExit(
        "DEEPSEEK_API_KEY not set. Copy .env.example to .env and add your key."
    )

with open(prd_path, "r", encoding="utf-8") as f:
    prd = f.read()

system = """你是 Task Master 任务生成器。根据 PRD 生成开发任务列表，输出严格 JSON，格式如下：
{
  "tasks": [
    {
      "id": 1,
      "title": "任务标题",
      "description": "简短描述",
      "details": "详细实现说明，含技术栈、文件路径、关键参数",
      "testStrategy": "验收方式",
      "priority": "high",
      "dependencies": [],
      "status": "pending",
      "subtasks": []
    }
  ],
  "metadata": {
    "projectName": "小说阅读器",
    "totalTasks": 20,
    "sourceFile": ".taskmaster/docs/prd.txt",
    "generatedAt": "2026-06-21"
  }
}

要求：
1. 生成 18-22 个顶层任务，覆盖 POC1、POC2、MVP P0/P1 功能
2. 任务顺序符合依赖：Flutter 工程 -> Drift Schema -> POC1 -> POC2 -> MVP 各模块
3. 使用中文标题和描述
4. 引用具体技术：Flutter、Drift、epubx、flutter_widget_from_html、ContentBlock、known_words 等
5. priority 只能是 high、medium、low 之一
6. 只输出 JSON，无其他文字"""

payload = {
    "model": "deepseek-chat",
    "messages": [
        {"role": "system", "content": system},
        {"role": "user", "content": f"根据以下 PRD 生成任务列表：\n\n{prd[:35000]}"},
    ],
    "max_tokens": 16000,
    "temperature": 0.2,
    "response_format": {"type": "json_object"},
}

req = urllib.request.Request(
    "https://api.deepseek.com/chat/completions",
    data=json.dumps(payload).encode("utf-8"),
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
    },
)
print("Calling DeepSeek API...")
resp = urllib.request.urlopen(req, timeout=180)
result = json.loads(resp.read().decode("utf-8"))
content = result["choices"][0]["message"]["content"]
data = json.loads(content)

tasks_file = {
    "master": {
        "tasks": data.get("tasks", []),
        "metadata": data.get(
            "metadata",
            {
                "projectName": "小说阅读器",
                "totalTasks": len(data.get("tasks", [])),
                "sourceFile": ".taskmaster/docs/prd.txt",
                "generatedAt": datetime.datetime.now().isoformat(),
            },
        ),
    }
}

out_dir = os.path.join(taskmaster_dir, "tasks")
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "tasks.json")
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(tasks_file, f, ensure_ascii=False, indent=2)

print("Written:", out_path)
print("Task count:", len(tasks_file["master"]["tasks"]))
