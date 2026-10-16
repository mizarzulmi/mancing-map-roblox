-- Kamera review "mercusuar" (Edit mode). Jalankan lalu screen_capture:
--   python scripts/studio_mcp.py luau scripts/camera/mercusuar.luau --dm Edit
--   python scripts/studio_mcp.py call screen_capture "{}" --out build/captures/mercusuar.png
local camera = workspace.CurrentCamera
camera.FieldOfView = 70
camera.CFrame = CFrame.lookAt(Vector3.new(150, 30, 105), Vector3.new(220, 30, 180))
print("[Kamera] mercusuar siap")
