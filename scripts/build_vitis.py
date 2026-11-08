import os
import sys
import vitis

root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ws = os.path.join(root, "vitis_game_v2")
xsa = os.path.join(root, "Game_Datapath_V2.xsa")

print(f"Opening Vitis workspace: {ws}")
client = vitis.create_client()
client.set_workspace(path=ws)

print("Listing components...")
comps = client.list_components()
print(f"Components found: {comps}")

platform_name = "platformgame_platform_v2"
print(f"Getting platform {platform_name}...")
platform = client.get_component(name=platform_name)

print(f"Updating hardware with {xsa}...")
try:
    platform.update_hw(hw_design=xsa)
except Exception as e:
    print(f"update_hw warning/info: {e}")

print("Building platform...")
platform.build()

app_name = "hdmi_game_app_v2"
print(f"Building application {app_name}...")
app = client.get_component(name=app_name)
app.build()

print("VITIS_BUILD_COMPLETE")

