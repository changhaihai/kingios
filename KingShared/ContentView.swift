import Foundation
import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @State private var tab = 0
    @State private var calibration = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            KingTheme.page.ignoresSafeArea()
            VStack(spacing: 0) {
                if tab == 0 { home } else { about }
                Divider().overlay(KingTheme.border)
                HStack(spacing: 0) {
                    tabButton("house.fill", "主页", 0)
                    tabButton("info.circle.fill", "关于", 1)
                }.frame(height: 52).background(KingTheme.header)
            }
            if showSettings { SettingsSheet(isPresented: $showSettings, calibration: $calibration).environmentObject(state) }
        }
        .onAppear { loadSettings() }
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) { BrandMark(); VStack(alignment: .leading, spacing: 2) { Text("王者共享").font(.system(size: 17, weight: .bold)); Text("实时对局战术地图 · v1.0.0").font(.system(size: 11)).foregroundStyle(KingTheme.secondary) }; Spacer() }
                HStack(spacing: 7) { Circle().fill(state.connected ? KingTheme.green : KingTheme.muted).frame(width: 7, height: 7); Text(state.status).font(.system(size: 11)).foregroundStyle(KingTheme.secondary); Spacer(); if let date = state.lastFrameAt { Text(date, style: .time).font(.system(size: 10)).foregroundStyle(KingTheme.muted) } }
                    .padding(.horizontal, 11).frame(height: 36).background(KingTheme.field).overlay(RoundedRectangle(cornerRadius: 6).stroke(KingTheme.border)).clipShape(RoundedRectangle(cornerRadius: 6))
                KingCard { VStack(alignment: .leading, spacing: 8) { Text("连接房间").font(.system(size: 15, weight: .bold)); Text("输入房间号后开始共享").font(.system(size: 11)).foregroundStyle(KingTheme.secondary); TextField("请输入房间号", text: $state.room).textInputAutocapitalization(.never).autocorrectionDisabled().padding(.horizontal, 11).frame(height: 44).background(KingTheme.field).overlay(RoundedRectangle(cornerRadius: 6).stroke(KingTheme.border)).clipShape(RoundedRectangle(cornerRadius: 6)); Button("连接并开启绘制") { state.connect() }.buttonStyle(KingButtonStyle(primary: true)) } }
                HStack(spacing: 7) { Button("悬浮设置") { showSettings = true }.buttonStyle(KingButtonStyle()); Button("关闭绘制") { state.stop() }.buttonStyle(KingButtonStyle(destructive: true)) }
                KingCard { HStack { VStack(alignment: .leading, spacing: 3) { Text("HUD 安全保护").font(.system(size: 14, weight: .bold)); Text(state.settings.secureOverlay ? "已开启 · 防截图 / 防录屏" : "已关闭 · 允许系统捕获").font(.system(size: 11)).foregroundStyle(KingTheme.secondary) }; Spacer(); Toggle("", isOn: Binding(get: { state.settings.secureOverlay }, set: { state.settings.secureOverlay = $0; state.saveSettings() })).labelsHidden().tint(KingTheme.green) } }
                Button("打开网站") { UIApplication.shared.open(URL(string: "https://king.weilua.top")!) }.buttonStyle(KingButtonStyle())
                if state.connected { KingCard { VStack(alignment: .leading, spacing: 8) { Text("实时 HUD 预览").font(.system(size: 14, weight: .bold)); ZStack(alignment: .top) { MapHUDView(frame: state.frame, settings: state.settings, showCalibration: calibration).frame(height: 280); TopInfoHUDView(enemies: state.frame.heroes.filter { !$0.ownTeam }, settings: state.settings).padding(.top, 8) }.frame(maxWidth: .infinity).background(Color.black.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 6)) } } }
            }.padding(16)
        }
    }

    private var about: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                KingCard {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("关于").font(.system(size: 17, weight: .bold))
                        Text("王者共享 v1.0.0").font(.system(size: 12)).foregroundStyle(KingTheme.secondary)
                        Text("轻量·稳定的实时地图共享客户端").font(.system(size: 11)).foregroundStyle(KingTheme.secondary)
                    }
                }
                KingCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("服务信息").font(.system(size: 14, weight: .bold))
                        Text("king.weilua.top").font(.system(size: 11)).foregroundStyle(KingTheme.secondary)
                        Text("iOS 版本使用应用内 HUD；录屏广播可通过 ReplayKit 扩展接入.").font(.system(size: 11)).foregroundStyle(KingTheme.secondary)
                    }
                }
                KingCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("鸣谢").font(.system(size: 14, weight: .bold))
                            Spacer()
                            Text("9 位").font(.system(size: 12)).foregroundStyle(KingTheme.gold)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(["Detector", "野马", "柠檬", "锤子", "鲁班", "卡卡", "S", "归零", "猴子"], id: \.self) { name in
                                VStack(spacing: 3) {
                                    Text(String(name.prefix(1))).font(.system(size: 13, weight: .bold))
                                        .frame(width: 34, height: 34)
                                        .background(KingTheme.card)
                                        .overlay(Circle().stroke(KingTheme.borderLight))
                                        .clipShape(Circle())
                                    Text(name).font(.system(size: 10, weight: .bold)).lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func tabButton(_ icon: String, _ title: String, _ value: Int) -> some View { Button { tab = value } label: { VStack(spacing: 2) { Image(systemName: icon).font(.system(size: 16)); Text(title).font(.system(size: 10)) }.foregroundStyle(tab == value ? KingTheme.gold : KingTheme.muted).frame(maxWidth: .infinity) } }
    private func loadSettings() { var d = DisplaySettings(); let p = UserDefaults.standard; d.heroes = p.object(forKey: "heroes") as? Bool ?? true; d.resources = p.object(forKey: "resources") as? Bool ?? true; d.minions = p.object(forKey: "minions") as? Bool ?? true; d.towers = p.object(forKey: "towers") as? Bool ?? true; d.topInfo = p.object(forKey: "topInfo") as? Bool ?? true; d.hideOwnTeam = p.object(forKey: "hideOwnTeam") as? Bool ?? false; d.opacity = p.object(forKey: "opacity") as? Double ?? 1; d.avatarScale = p.object(forKey: "avatarScale") as? Double ?? 1; d.offsetX = p.object(forKey: "offsetX") as? Double ?? 0; d.offsetY = p.object(forKey: "offsetY") as? Double ?? 0; d.mapSpacing = p.object(forKey: "mapSpacing") as? Double ?? 0; d.secureOverlay = p.object(forKey: "secureOverlay") as? Bool ?? false; state.settings = d }
}

struct SettingsSheet: View {
    @EnvironmentObject private var state: AppState
    @Binding var isPresented: Bool
    @Binding var calibration: Bool
    @State private var tab = 0
    var body: some View {
        VStack(spacing: 0) {
            HStack { BrandMark().scaleEffect(0.75); Text("王者共享 · 房间 \(state.room.isEmpty ? "未连接" : state.room)").font(.system(size: 13, weight: .bold)); Spacer(); Button { isPresented = false } label: { Image(systemName: "xmark").frame(width: 28, height: 28) }.buttonStyle(.bordered) }.padding(12)
            Divider().overlay(KingTheme.border)
            Picker("", selection: $tab) { Text("显示").tag(0); Text("调节").tag(1) }.pickerStyle(.segmented).padding(10)
            ScrollView { if tab == 0 { displayPage } else { adjustPage } }.frame(maxHeight: .infinity)
            Text("● \(state.connected ? "已连接" : "未连接") · 应用内 HUD").font(.system(size: 10)).foregroundStyle(state.connected ? KingTheme.green : KingTheme.muted).padding(10)
        }.frame(maxWidth: 420, maxHeight: 620).background(KingTheme.page).overlay(RoundedRectangle(cornerRadius: 12).stroke(KingTheme.border)).clipShape(RoundedRectangle(cornerRadius: 12)).padding(18).background(.black.opacity(0.55).ignoresSafeArea())
    }
    private var displayPage: some View { VStack(spacing: 2) { ToggleRow("英雄头像与血条", keyPath: \.heroes); ToggleRow("野怪与资源", keyPath: \.resources); ToggleRow("防御塔血量", keyPath: \.towers); ToggleRow("顶部信息", keyPath: \.topInfo); ToggleRow("不绘制己方英雄", keyPath: \.hideOwnTeam) }.padding(.horizontal, 14) }
    private var adjustPage: some View { VStack(spacing: 10) { SliderRow("整体 X", value: $state.settings.offsetX, range: -600...600); SliderRow("整体 Y", value: $state.settings.offsetY, range: -600...600); SliderRow("整体间隔", value: $state.settings.mapSpacing, range: -50...100); SliderRow("头像大小", value: $state.settings.avatarScale, range: 0.6...1.8); SliderRow("不透明度", value: $state.settings.opacity, range: 0.3...1); SliderRow("顶栏大小", value: $state.settings.topSize, range: 0.6...1.8); Toggle("显示校准框", isOn: $calibration).tint(KingTheme.green); Button("自动适配当前屏幕") { state.settings.offsetX = 0; state.settings.offsetY = 0; state.settings.mapSpacing = 0; state.saveSettings() }.buttonStyle(KingButtonStyle()) }.padding(14) }
}

struct ToggleRow: View {
    @EnvironmentObject private var state: AppState
    let title: String
    let keyPath: WritableKeyPath<DisplaySettings, Bool>
    var body: some View { HStack { Text(title).font(.system(size: 13)); Spacer(); Toggle("", isOn: Binding(get: { state.settings[keyPath: keyPath] }, set: { state.settings[keyPath: keyPath] = $0; state.saveSettings() })).labelsHidden().tint(KingTheme.green) }.padding(.vertical, 7) }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var body: some View { VStack(alignment: .leading, spacing: 3) { HStack { Text(title).font(.system(size: 12)).foregroundStyle(KingTheme.secondary); Spacer(); Text(String(format: "%.0f", value)).font(.system(size: 12, weight: .bold)).foregroundStyle(KingTheme.gold) }; Slider(value: $value, in: range).tint(KingTheme.gold) } }
}
