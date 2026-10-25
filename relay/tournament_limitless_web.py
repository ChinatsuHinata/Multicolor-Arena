"""Read public live pages when Limitless's completed-tournament API is unavailable."""
import re
from datetime import datetime, timezone
from html.parser import HTMLParser
from urllib.error import HTTPError, URLError
from urllib.request import Request, build_opener


class Node:
    def __init__(self, tag="", attrs=()):
        self.tag, self.attrs, self.children = tag, dict(attrs), []

    def find(self, tag=None, cls=None):
        result = []
        for child in self.children:
            if isinstance(child, Node):
                if (tag is None or child.tag == tag) and (cls is None or cls in child.attrs.get("class", "").split()):
                    result.append(child)
                result.extend(child.find(tag, cls))
        return result

    def text(self):
        return " ".join(c.text() if isinstance(c, Node) else c for c in self.children).strip()


class Document(HTMLParser):
    def __init__(self, html):
        super().__init__(convert_charrefs=True)
        self.root = Node()
        self.stack = [self.root]
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs)
        self.stack[-1].children.append(node)
        if tag not in ("area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"):
            self.stack.append(node)

    def handle_endtag(self, tag):
        for index in range(len(self.stack) - 1, 0, -1):
            if self.stack[index].tag == tag:
                del self.stack[index:]
                break

    def handle_data(self, data):
        if self.stack[-1].tag not in ("script", "style"):
            self.stack[-1].children.append(data)


def page(external_id, endpoint):
    from tournament_limitless import BASE, MAX_BYTES, NoRedirect, SyncError
    request = Request(f"{BASE}/tournament/{external_id}/{endpoint}", headers={"User-Agent": "Multicolor-Arena/Limitless-Sync"})
    try:
        with build_opener(NoRedirect()).open(request, timeout=5) as response:
            raw = response.read(MAX_BYTES + 1)
        if len(raw) > MAX_BYTES:
            raise ValueError("Limitless 网页过大")
        return Document(raw.decode("utf-8")).root
    except HTTPError as exc:
        delay = exc.headers.get("Retry-After", "120")
        raise SyncError(f"Limitless 网页返回 HTTP {exc.code}，保留已有数据", int(delay) if delay.isdigit() else 120) from None
    except (URLError, TimeoutError, OSError, UnicodeError):
        raise ValueError("无法读取 Limitless 公开网页，请稍后重试") from None


def required(node, tag=None, cls=None):
    matches = node.find(tag, cls)
    if not matches:
        raise ValueError("Limitless 网页结构不受支持，未替换已有数据")
    return matches[0]


def metadata(doc):
    header = required(doc, cls="tournament-header")
    title = required(header, cls="name").text()
    basics = required(doc, "table", "basics")
    times = [n.attrs["data-time"] for n in basics.find("td") if "data-time" in n.attrs]
    if not times or not times[0].isdigit():
        raise ValueError("Limitless 未公布比赛时间")
    date = datetime.fromtimestamp(int(times[0]) / 1000, timezone.utc).isoformat()
    phases = []
    for phase in required(doc, cls="structure").find(cls="phase"):
        label = required(phase, cls="rounds").text()
        match = re.match(r"(?:(\d+) )?(Swiss Rounds?|Single Elimination Rounds?|Round Robin Rounds?|Single Elimination Bracket|Double Elimination Bracket) - (BO[1235])", label)
        if not match:
            raise ValueError("Limitless 网页赛制未知，无法自动导入")
        kind = "SWISS" if match[2].startswith("Swiss") else "ROUND_ROBIN" if match[2].startswith("Round Robin") else "DOUBLE_BRACKET" if match[2].startswith("Double") else "SINGLE_BRACKET" if "Bracket" in match[2] else "SINGLE_ELIMINATION"
        phases.append({"phase": len(phases) + 1, "type": kind, "rounds": int(match[1] or 1), "mode": match[3]})
    description = doc.find(cls="description")
    return {"name": title, "date": date, "description": description[0].text()[:2000] if description else "", "phases": phases, "finished": False}


def players(doc, external_id):
    containers = doc.find(cls="standings") or doc.find(cls="players")
    if not containers:
        raise ValueError("Limitless 尚未公开可核对的选手名单")
    entries = []
    for row in containers[0].find("tr"):
        links = [a for a in row.find("a") if a.attrs.get("href", "").startswith(f"/tournament/{external_id}/player/")]
        if not links:
            continue
        link = links[0]
        player = link.attrs["href"].rsplit("/", 1)[-1]
        record = next((match for cell in row.find("td") if (match := re.fullmatch(r"(\d+)\s*-\s*(\d+)\s*-\s*(\d+)", cell.text()))), None)
        entries.append({"player": player, "name": link.text(), "placing": int(row.attrs.get("data-placing", 0)),
                        "record": dict(zip(("wins", "losses", "ties"), map(int, record.groups()))) if record else {}})
    return entries


def matches(doc, external_id, phases):
    tables = [n for n in doc.find("table") if n.attrs.get("data-tournament") == external_id and "data-round" in n.attrs]
    if not tables:
        raise ValueError("Limitless 当前签表格式暂不支持导入，请在来源网站查看")
    table = tables[0]
    absolute = int(table.attrs["data-round"])
    number = absolute
    phase = None
    for entry in phases:
        if number <= entry["rounds"]:
            phase = entry
            break
        number -= entry["rounds"]
    if not phase or phase["type"] in ("SINGLE_BRACKET", "DOUBLE_BRACKET"):
        raise ValueError("Limitless 实时淘汰树请在来源网站查看，当前不能导入游戏内")
    result = []
    for row in table.find("tr"):
        if "data-match" not in row.attrs:
            continue
        participants = row.find("td", "player")
        if not 1 <= len(participants) <= 2:
            raise ValueError("Limitless 网页对阵选手无效")
        ids = [p.attrs.get("data-id", "") for p in participants]
        completed = row.attrs.get("data-completed")
        if completed not in ("0", "1"):
            raise ValueError("Limitless 网页赛果状态未知")
        winner = row.attrs.get("data-winner", "") if completed == "1" else None
        if winner in ("0", "-1"):
            winner = int(winner)
        result.append({"phase": phase["phase"], "round": number, "table": int(required(row, "td").text()),
                       "player1": ids[0], "player2": ids[1] if len(ids) == 2 else "", "winner": winner})
    if not result:
        raise ValueError("Limitless 签表尚未公开")
    return absolute, result


def fetch(external_id):
    doc = page(external_id, "details")
    details = metadata(doc)
    links = {n.attrs.get("href", "") for n in required(doc, cls="tournament-header").find("a")}
    base = f"/tournament/{external_id}/"
    started = base + "pairings" in links
    details["started"] = started
    roster = players(page(external_id, "standings" if started else "players"), external_id)
    if not started:
        return details, roster, []
    current = page(external_id, "pairings")
    latest, pairings = matches(current, external_id, details["phases"])
    rounds = {int(m[1]) for a in current.find("a") if (m := re.fullmatch(re.escape(base) + r"pairings\?round=(\d+)", a.attrs.get("href", "")))}
    if not rounds or rounds != set(range(1, latest + 1)) or latest > 32:
        raise ValueError("Limitless 网页历轮签表不完整或超过 32 轮，未替换已有数据")
    for number in sorted(rounds - {latest}):
        actual, previous = matches(page(external_id, f"pairings?round={number}"), external_id, details["phases"])
        if actual != number:
            raise ValueError("Limitless 历轮页面与请求不符")
        pairings.extend(previous)
    return details, roster, pairings
