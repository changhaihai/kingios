$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Required = @(
    'project.yml', 'build.sh', 'Resources/Info.plist', 'Resources/SharedHUD.entitlements',
    'Sources/main.m', 'Sources/SHAppDelegate.m', 'Sources/SHHUDAppDelegate.m',
    'Sources/SHSystemOverlay.m', 'Sources/SHProcessController.m', 'Sources/SHRoomSocket.m',
    'Sources/SHBattleFrame.m', 'Sources/SHHUDCanvasView.m', 'Sources/SHControlViewController.m'
)
foreach ($Item in $Required) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $Item))) { throw "missing: $Item" }
}
[xml](Get-Content -Raw -LiteralPath (Join-Path $Root 'Resources/Info.plist')) | Out-Null
[xml](Get-Content -Raw -LiteralPath (Join-Path $Root 'Resources/SharedHUD.entitlements')) | Out-Null
$All = Get-Content -Raw -LiteralPath (Join-Path $Root 'Sources/SHSystemOverlay.m')
foreach ($Token in @('SBSAccessibilityWindowHostingController','registerWindowWithContextID:atLevel:','_ignoresHitTest')) {
    if (-not $All.Contains($Token)) { throw "missing overlay token: $Token" }
}
$Main = Get-Content -Raw -LiteralPath (Join-Path $Root 'Sources/main.m')
foreach ($Mode in @('-hud','-check','-exit')) { if (-not $Main.Contains($Mode)) { throw "missing process mode: $Mode" } }
$Socket = Get-Content -Raw -LiteralPath (Join-Path $Root 'Sources/SHRoomSocket.m')
foreach ($Protocol in @('subscribe[==]','gameData##','ping##')) { if (-not $Socket.Contains($Protocol)) { throw "missing protocol token: $Protocol" } }
$Entitlements = Get-Content -Raw -LiteralPath (Join-Path $Root 'Resources/SharedHUD.entitlements')
foreach ($Entitlement in @('platform-application','com.apple.private.security.no-sandbox','com.apple.springboard.accessibility-window-hosting','com.apple.QuartzCore.displayable-context')) {
    if (-not $Entitlements.Contains($Entitlement)) { throw "missing entitlement: $Entitlement" }
}
Write-Output "VALIDATION_OK files=$($Required.Count) modes=3 protocol=3 overlay=3 entitlements=4"
