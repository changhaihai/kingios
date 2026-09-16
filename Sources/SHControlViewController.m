@@
-    [stack addArrangedSubview:[self switchRow:@"英雄头像与血条" key:@"heroes" value:s.heroes]];
-    [stack addArrangedSubview:[self switchRow:@"野怪与资源" key:@"resources" value:s.resources]];
-    [stack addArrangedSubview:[self switchRow:@"兵线" key:@"minions" value:s.minions]];
-    [stack addArrangedSubview:[self switchRow:@"防御塔血量" key:@"towers" value:s.towers]];
-    [stack addArrangedSubview:[self switchRow:@"隐藏己方英雄" key:@"hideOwnTeam" value:s.hideOwnTeam]];
-    [stack addArrangedSubview:[self switchRow:@"顶部敌方信息" key:@"topInfo" value:s.topInfo]];
-    [stack addArrangedSubview:[self switchRow:@"安全绘制层" key:@"secureOverlay" value:s.secureOverlay]];
+    [stack addArrangedSubview:[self switchRow:@"英雄头像与血条" key:@"heroes" value:s.heroes]];
+    [stack addArrangedSubview:[self switchRow:@"仅绘制头像 (性能模式)" key:@"onlyAvatars" value:s.onlyAvatars]];
+    [stack addArrangedSubview:[self switchRow:@"模拟数据 (mock)" key:@"mockMode" value:s.mockMode]];
+    // 旧的详细项保留在高级设置中，默认隐藏以简化 UI
+    [stack addArrangedSubview:[self switchRow:@"野怪与资源 (高级)" key:@"resources" value:s.resources]];
+    [stack addArrangedSubview:[self switchRow:@"兵线 (高级)" key:@"minions" value:s.minions]];
+    [stack addArrangedSubview:[self switchRow:@"防御塔血量 (高级)" key:@"towers" value:s.towers]];
+    [stack addArrangedSubview:[self switchRow:@"隐藏己方英雄 (高级)" key:@"hideOwnTeam" value:s.hideOwnTeam]];
+    [stack addArrangedSubview:[self switchRow:@"顶部敌方信息 (高级)" key:@"topInfo" value:s.topInfo]];
+    [stack addArrangedSubview:[self switchRow:@"安全绘制层 (高级)" key:@"secureOverlay" value:s.secureOverlay]];
@@
-    s.heroes=self.switches[@"heroes"].on; s.resources=self.switches[@"resources"].on; s.minions=self.switches[@"minions"].on; s.towers=self.switches[@"towers"].on; s.hideOwnTeam=self.switches[@"hi[...]
+    s.heroes=self.switches[@"heroes"].on;
+    s.onlyAvatars=self.switches[@"onlyAvatars"].on;
+    s.mockMode=self.switches[@"mockMode"].on;
+    s.resources=self.switches[@"resources"].on; s.minions=self.switches[@"minions"].on; s.towers=self.switches[@"towers"].on; s.hideOwnTeam=self.switches[@"hi[...]
