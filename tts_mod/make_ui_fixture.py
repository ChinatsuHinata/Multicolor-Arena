"""Create a MoonSharp fixture to check generated UI without launching TTS."""

import json
import re
from pathlib import Path

from verify_build import embedded_json


HERE = Path(__file__).resolve().parent


def lua_literal(value):
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return "{" + ",".join(lua_literal(item) for item in value) + "}"
    if isinstance(value, dict):
        return "{" + ",".join("[" + lua_literal(key) + "]=" + lua_literal(item)
                            for key, item in value.items()) + "}"
    raise TypeError(type(value))


def main():
    save = json.loads((HERE / "Multicolour_Deck_Builder.json").read_text(encoding="utf-8"))
    lua = save["LuaScript"]
    for name in ("cards", "assets"):
        data = embedded_json(lua, name)
        pattern = rf"local {name} = JSON.decode\(\[====\[.*?\]====\]\)"
        lua = re.sub(pattern, lambda _: f"local {name} = {lua_literal(data)}", lua, count=1, flags=re.DOTALL)
    fixture = """UI={setXml=function(s) last_xml=s end}
JSON={decode=function(s) return {} end, encode=function(t) return '{}' end}
spawned_data={}
spawnObjectData=function(p) spawned_data[#spawned_data+1]=p.data; return {setLock=function() end, setName=function() end,
    addTag=function() end, isDestroyed=function() return false end, destruct=function() end} end
""" + lua + "\nonLoad('')\nonDeckClick({getPointerPosition=function() return {x=0,y=0,z=0} end}, nil, 'toggle')\n"
    precon_path = sorted((HERE.parent / "deck/预设卡组").glob("*.mdeck"))[0]
    precon = json.loads(precon_path.read_text(encoding="utf-8"))["deck"]
    fixture += "\nprecon=" + lua_literal(precon) + "\n"
    fixture += """p={getPointerPosition=function() return {x=0,y=0,z=0} end}
JSON.decode=function(s) return precon end
onDeckField(p,'fixture','deck_code')
onDeckClick(p,nil,'import')
onDeckClick(p,nil,'spawn')
"""
    target = HERE / "ui_fixture.lua"
    target.write_text(fixture, encoding="utf-8")
    print(target)


if __name__ == "__main__":
    main()
