-- Kamera review "lautdalam" (Edit mode). Jalankan lalu screen_capture:
--   python scripts/studio_mcp.py luau scripts/camera/lautdalam.luau --dm Edit
--   python scripts/studio_mcp.py call screen_capture "{}" --out build/captures/lautdalam.png
local camera = workspace.CurrentCamera
camera.FieldOfView = 70
camera.CFrame = CFrame.lookAt(Vector3.new(-30, 40, 715), Vector3.new(60, 4, 820))
print("[Kamera] lautdalam siap")
