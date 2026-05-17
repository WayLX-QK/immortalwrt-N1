#!/bin/bash
# ==================================================================================
# OpenWrt 编译前自定义处理脚本 (DIY - Do It Yourself)
# 执行时机：在执行make defconfig之后、make download之前
# 脚本功能：注入第三方软件源、修改系统默认配置、替换主题资源等
# 运行环境：OpenWrt源码根目录 ($GITHUB_WORKSPACE/openwrt)
# ==================================================================================

# ==================================================================================
# 【功能区1】移除不需要的软件包 - 减小固件体积，清理预置功能
# 【移除策略】根据项目需求禁用不必要的基础包
# ==================================================================================

# 【V2Ray地理位置数据】注释掉的移除命令示例
# 业务逻辑：v2ray-geodata包含GeoIP/Geosite数据，体积较大（约50MB）
# 如果不需要V2Ray的路由规则，可以移除该包
# 实际执行：rm -rf feeds/packages/net/v2ray-geodata
# 注意：此行被注释，如需移除请取消注释
#rm -rf feeds/packages/net/v2ray-geodata


# ==================================================================================
# 【功能区2】添加第三方软件源 - 扩展OpenWrt软件包生态
# 【软件源选择原则】
#   1. 稳定性：选择维护活跃、社区认可的成熟项目
#   2. 兼容性：确保与当前OpenWrt版本兼容
#   3. 功能性：补充OpenWrt官方源缺失的功能
# ==================================================================================

# ==================================================================================
# 【第三方插件开关】如需禁用某个插件，请注释对应的git clone和配置行
# 禁用方法：
#   1. 将git clone行注释（行首加#）
#   2. 将echo追加配置行注释（行首加#）
#   3. 编译时不会下载和安装该插件
# ==================================================================================

# 【Amlogic N1盒子管理插件】- 斐讯N1专用硬件管理工具
# 项目地址：https://github.com/ophub/luci-app-amlogic
# 功能说明：N1盒子的专用管理界面，支持：
#   - 内核在线升级（flippy内核/官方内核切换）
#   - 盒子模式切换（ubinize/EMMC/KVM等）
#   - 温度/频率监控
#   - 引导分区管理
#   - USB启动/EMMC启动切换
# 克隆策略：--depth=1浅克隆，只获取最新版本，减少传输量
# 【状态】：如需禁用，请注释下面两行
# git clone --depth=1 https://github.com/ophub/luci-app-amlogic package/amlogic

# 【Linkease NAS管理插件】- 网络存储管理界面
# 项目地址：https://github.com/linkease/luci-app-linkease
# 功能说明：易有云/NAS相关管理功能
#   - 文件浏览器
#   - SMB/AFP/NFS共享管理
#   - DDNS配置（与云添加合作）
#   - 存储设备监控
# 克隆说明：未使用--depth参数，保留完整历史便于后续更新
# 【状态】：如需禁用，请注释下面两行
# git clone  https://github.com/linkease/luci-app-linkease package/linkease

# 【Lucky插件】- 网络工具集成
# 项目地址：https://github.com/gdy666/luci-app-lucky
# 功能说明：整合多种网络工具
#   - 端口转发管理
#   - 内网穿透（frp配置）
#   - 动态域名（DDNS）
#   - 网络诊断工具
# 特性说明：Lucky是一个较新的项目，社区活跃度高
# 【状态】：如需禁用，请注释下面两行
# git clone  https://github.com/gdy666/luci-app-lucky.git package/lucky

# ==================================================================================
# 【UU游戏加速器】- 网络游戏加速功能
# 项目地址：https://github.com/kenjiokabe/luci-app-uuplugin (示例)
# 备选项目：https://github.com/SuLingGG/luci-app-uugamebooster
# 功能说明：网易UU路由器插件，实现游戏加速
#   - 支持PC/手机/主机全平台游戏加速
#   - 智能选路减少延迟和丢包
#   - 兼容OpenClash共存
# 注意事项：
#   1. 需要UU账号（免费/付费版均可）
#   2. 需要在插件中登录UU账号获取加速授权
#   3. 加速原理：创建加密隧道到UU加速服务器
# 【状态】：如需启用，取消下面注释即可
# git clone --depth=1 https://github.com/SuLingGG/luci-app-uugamebooster package/luci-app-uugamebooster

# ==================================================================================
# 【功能区3】OpenClash核心预置 - 预留的Clash核心下载功能
# 【说明】该功能已被注释，当前OpenClash插件会在首次运行时自动下载核心
# 备选方案：如果需要预置Clash核心，可取消注释preset-clash-core.sh脚本
# ==================================================================================

# 【OpenClash核心下载脚本】预留的自动化下载功能
# 脚本位置：$GITHUB_WORKSPACE/N1/preset-clash-core.sh
# 执行条件：需要预先准备好核心文件并添加执行权限
# 当前状态：已注释，如需预置核心请取消注释并提供核心文件
#chmod -R a+x $GITHUB_WORKSPACE/preset-clash-core.sh
#$GITHUB_WORKSPACE/N1/preset-clash-core.sh

# ==================================================================================
# 【功能区4】动态追加配置到.config - 向Kconfig追加软件包选择
# 【配置说明】追加在.config末尾的配置会在make defconfig时生效
# 【追加策略】确保追加的配置不与已有配置冲突
# ==================================================================================

# 【追加自定义插件包配置】将新增的LuCI应用添加到编译配置
# 追加内容说明：
#   - luci-app-amlogic: N1硬件管理插件（来自上面的git clone）
#   - luci-app-linkease: NAS管理插件（来自上面的git clone）
#   - luci-app-lucky: 网络工具插件（来自上面的git clone）
#   - luci-app-uugamebooster: UU游戏加速器（来自上面的git clone）
# 追加方式：echo重定向追加，>>表示追加而不是覆盖
# 【重要】：请与上方git clone保持同步，注释掉git clone时也要注释对应配置
echo "
# 插件 (请与上方git clone保持同步)
# CONFIG_PACKAGE_luci-app-amlogic=y
# CONFIG_PACKAGE_luci-app-linkease=y
# CONFIG_PACKAGE_luci-app-lucky=y
# CONFIG_PACKAGE_luci-app-uugamebooster=y
" >> .config


# ==================================================================================
# 【功能区5】系统默认配置修改 - 修改OpenWrt出厂默认设置
# 【修改原则】符合目标使用场景的默认配置，减少首次配置工作量
# ==================================================================================

# 【修改默认IP地址】从192.168.1.1改为192.168.2.2
# 业务逻辑：
#   - 斐讯N1常作为二级路由器或旁路由使用
#   - 192.168.2.x网段可避免与主路由192.168.1.x冲突
#   - 便于网络中有多个设备时区分和管理
# 修改文件：package/base-files/files/bin/config_generate
# 该文件是OpenWrt网络配置生成器，决定首次启动的默认IP
sed -i 's/192.168.1.1/192.168.2.2/g' package/base-files/files/bin/config_generate

# 【修改默认主题配置】将默认主题从design/bootstrap改为argon
# 业务逻辑：
#   - luci-theme-argon是本项目选用的现代主题
#   - 修改feeds/luci/collections/luci/Makefile确保默认安装argon
#   - 避免编译后默认主题为其他主题需要手动切换
# 修改点1：将luci-theme-design替换为argon
sed -i 's/luci-theme-design/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
# 修改点2：将luci-theme-bootstrap替换为argon（双保险确保生效）
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 【修改默认主机名】从ImmortalWrt改为OpenWrt
# 业务逻辑：
#   - 移除上游品牌标识，使用通用的OpenWrt名称
#   - 便于在网络设备列表中识别
#   - 符合中性化定制需求
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate


# ==================================================================================
# 【功能区6】主题资源文件替换 - 自定义Argon主题视觉元素
# 【替换说明】将项目预设的图片资源覆盖到Argon主题目录
# 【资源来源】$GITHUB_WORKSPACE/argon/目录
# ==================================================================================

# 【Argon主题背景图】替换默认背景为自定义背景
# 业务逻辑：使用自定义背景图增加品牌辨识度
# 目标路径：feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/
cp -f $GITHUB_WORKSPACE/argon/img/bg1.jpg feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
cp -f $GITHUB_WORKSPACE/argon/img/argon.svg feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/argon.svg

# 【网站图标替换】替换浏览器标签页显示的favicon
# 业务逻辑：使用自定义图标增强品牌辨识度
# 目标文件：favicon.ico (16x16, 32x32, 48x48等多种尺寸)
cp -f $GITHUB_WORKSPACE/argon/favicon.ico feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/favicon.ico

# 【Android/iOS应用图标】替换PWA/webapp的桌面图标
# 业务逻辑：当用户将网页添加到桌面时的显示图标
# 包含尺寸：
#   - android-icon-192x192.png: Android高密度屏
#   - apple-icon-144x144.png: iOS Retina屏幕
#   - apple-icon-60x60.png: iOS普通屏幕
#   - apple-icon-72x72.png: iPad普通屏幕
cp -f $GITHUB_WORKSPACE/argon/icon/android-icon-192x192.png feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/icon/android-icon-192x192.png
cp -f $GITHUB_WORKSPACE/argon/icon/apple-icon-144x144.png feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/icon/apple-icon-144x144.png
cp -f $GITHUB_WORKSPACE/argon/icon/apple-icon-60x60.png feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/icon/apple-icon-60x60.png
cp -f $GITHUB_WORKSPACE/argon/icon/apple-icon-72x72.png feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/icon/apple-icon-72x72.png

# 【标准尺寸favicon】替换各种标准尺寸的网页图标
# 用途：浏览器标签页、收藏夹、搜索结果等场景
# 包含尺寸：16x16, 32x32, 96x96像素
cp -f $GITHUB_WORKSPACE/argon/icon/favicon-16x16.png feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/icon/favicon-16x16.png
cp -f $GITHUB_WORKSPACE/argon/icon/favicon-32x32.png feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/icon/favicon-32x32.png
cp -f $GITHUB_WORKSPACE/argon/icon/favicon-96x96.png feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/icon/favicon-96x96.png

# 【Windows图标】替换Windows开始菜单/任务栏图标
# 用途：Windows设备访问时的显示图标
# 尺寸：ms-icon-144x144.png (144x144像素)
cp -f $GITHUB_WORKSPACE/argon/icon/ms-icon-144x144.png feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/icon/ms-icon-144x144.png

# ==================================================================================
# 【脚本结束】
# 本脚本完成的主要工作：
#   1. 克隆3个第三方LuCI应用插件
#   2. 追加3个插件到.config编译配置
#   3. 修改默认IP地址192.168.2.2
#   4. 修改默认主题为argon
#   5. 修改默认主机名为OpenWrt
#   6. 替换Argon主题的全部图标和背景资源
# 执行成功后会返回继续执行make download
# ==================================================================================

