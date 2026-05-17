#!/bin/bash
# ==================================================================================
# 斐讯N1 (Phicomm N1) 固件镜像生成脚本
# 目标平台：Amlogic S905D (ARM Cortex-A53, 4-core)
# 脚本功能：将OpenWrt rootfs转换为可烧录的IMG镜像文件
# 依赖环境：需要openwrt_packit工具链环境（make.env, public_funcs等）
# 执行入口：由GitHub Actions的unifreq/openwrt_packit调用
# ==================================================================================

# ==================================================================================
# 【阶段1】脚本初始化 - 环境变量加载和工作目录初始化
# ==================================================================================

# 【脚本开始标记】打印日志便于追踪执行流程
echo "========================= begin $0 ==========================="
# 【加载公共函数库】包含镜像创建、分区格式化等通用函数
# make.env：定义环境变量和工作路径
# public_funcs：包含create_image, create_partition, mount_fs等公共函数
source make.env
source public_funcs

# 【初始化工作环境】创建临时目录、设置环境变量、准备挂载点
# 业务逻辑：确保打包过程有足够的临时空间和正确的权限
init_work_env


# ==================================================================================
# 【阶段2】硬件平台识别参数 - 定义目标设备和芯片信息
# ==================================================================================

# 【硬件平台】Amlogic平台 - 适配S905/S905X/S905D/S912等芯片
# 业务逻辑：告诉打包系统使用Amlogic特有的引导方式（u-boot）
PLATFORM=amlogic
# 【SoC芯片型号】S905D - 斐讯N1使用的具体芯片型号
# 芯片规格：4x Cortex-A53 @ 1.5GHz, Mali-450 GPU, 1GB DDR3
SOC=s905d
# 【目标设备】n1 - 斐讯N1的设备代号
# 用于镜像命名和设备树选择
BOARD=n1

# 【WiFi支持开关】K510芯片WiFi支持配置
# 业务逻辑：N1硬件不支持内置WiFi，禁用避免驱动加载错误
# 注释说明：让N1一直有wifi可用，以减少抱怨（用户反馈）
# ENABLE_WIFI_K510=1 表示启用，=0 表示禁用
# 当前配置：禁用（0），因为N1没有内置WiFi模块
ENABLE_WIFI_K510=0

# 【内核子版本号】可传入的额外版本标识
# 用法：./mk_s905d_n1.sh -xxx 可添加后缀标识
# 示例：k5.15.50-xxx 表示5.15.50内核带自定义后缀
SUBVER=$1


# ==================================================================================
# 【阶段3】内核文件来源配置 - 指定用于固件的内核版本
# ==================================================================================

# 【内核标签】使用stable稳定版内核
# 备选选项：mainline（主线最新）、longterm（长期维护）
KERNEL_TAGS="stable"

# 【内核版本约束】mainline分支，版本>=5.4
# 业务逻辑：N1在5.4+内核上驱动支持最完善
# 说明：支持5.4、5.10、5.15、6.1等版本
KERNEL_BRANCHES="mainline:all:>=:5.4"

# 【内核模块包】内核ko模块的tarball归档
# 路径格式：{KERNEL_PKG_HOME}/modules-{KERNEL_VERSION}.tar.gz
# 包含：内核模块文件（*.ko）、模块依赖关系（modules.dep）
MODULES_TGZ=${KERNEL_PKG_HOME}/modules-${KERNEL_VERSION}.tar.gz
check_file ${MODULES_TGZ}

# 【内核启动文件】包含zImage或vmlinuz内核镜像
# 路径格式：{KERNEL_PKG_HOME}/boot-{KERNEL_VERSION}.tar.gz
# 包含：zImage内核镜像、initrd启动内存文件系统
BOOT_TGZ=${KERNEL_PKG_HOME}/boot-${KERNEL_VERSION}.tar.gz
check_file ${BOOT_TGZ}

# 【设备树文件】Device Tree Blob二进制文件集合
# 路径格式：{KERNEL_PKG_HOME}/dtb-amlogic-{KERNEL_VERSION}.tar.gz
# 包含：meson-gxl-s905d-phicomm-n1.dtb等设备树文件
DTBS_TGZ=${KERNEL_PKG_HOME}/dtb-amlogic-${KERNEL_VERSION}.tar.gz
check_file ${DTBS_TGZ}

# 【内核主版本号提取】从boot tarball中解析K510版本号
# 业务逻辑：某些驱动需要知道内核版本号进行条件适配
# 函数：get_k510_from_boot_tgz解析vmlinuz-{版本}中的版本字符串
K510=$(get_k510_from_boot_tgz "${BOOT_TGZ}" "vmlinuz-${KERNEL_VERSION}")
export K510
###########################################################################


# ==================================================================================
# 【阶段4】OpenWrt根文件系统来源 - 确定使用的rootfs tarball
# ==================================================================================

# 【获取rootfs归档】从编译产物中查找tar.gz格式的rootfs
# 函数：get_openwrt_rootfs_archive在bin/targets目录下查找
# 路径模式：openwrt/bin/targets/{target}/{subtarget}/*.tar.gz
OPWRT_ROOTFS_GZ=$(get_openwrt_rootfs_archive ${PWD})
check_file ${OPWRT_ROOTFS_GZ}
echo "Use $OPWRT_ROOTFS_GZ as openwrt rootfs!"

# 【目标镜像文件路径】最终输出的IMG文件完整路径
# 命名格式：openwrt_{SOC}_{BOARD}_{VERSION}_k{KERNEL_VERSION}{SUBVER}.img
# 示例：openwrt_s905d_n1_2024.05.17_k5.15.50.img
TGT_IMG="${WORK_DIR}/openwrt_${SOC}_${BOARD}_${OPENWRT_VER}_k${KERNEL_VERSION}${SUBVER}.img"


# ==================================================================================
# 【阶段5】补丁和脚本资源路径定义 - 所有需要注入的文件
# ==================================================================================
###########################################################################

# 【内核模块文件】额外的内核模块（可能需要手动加载的驱动）
KMOD="${PWD}/files/kmod"
# 【内核模块黑名单】需要禁用的内核模块（避免冲突）
KMOD_BLACKLIST="${PWD}/files/kmod_blacklist"

# 【MAC地址处理脚本】Perl脚本用于查找/计算MAC地址
# 业务逻辑：N1的网卡MAC地址需要特殊处理，避免冲突
MAC_SCRIPT2="${PWD}/files/find_macaddr.pl"
MAC_SCRIPT3="${PWD}/files/inc_macaddr.pl"

# 【CPU监控脚本】实时显示CPU使用率和频率
# 作用：让用户可以在终端直接查看系统负载
CPUSTAT_SCRIPT="${PWD}/files/cpustat"
CPUSTAT_SCRIPT_PY="${PWD}/files/cpustat.py"

# 【Web界面补丁】修改LuCI默认首页显示内容
INDEX_PATCH_HOME="${PWD}/files/index.html.patches"

# 【CPU核心选择脚本】获取当前运行核心
GETCPU_SCRIPT="${PWD}/files/getcpu"

# 【Flippy脚本】已废弃的N1专用脚本（历史兼容性保留）
FLIPPY="${PWD}/files/scripts_deprecated/flippy_cn"

# 【欢迎横幅】登录终端时显示的系统信息
BANNER="${PWD}/files/banner"

# ==================================================================================
# 【阶段5.1】2020年3月14日添加的资源
# ==================================================================================
# 【固件文件目录】包含WiFi固件、蓝牙固件等
FMW_HOME="${PWD}/files/firmware"
# 【SMB4补丁】启用SMB1协议的patch（兼容老旧Windows）
SMB4_PATCH="${PWD}/files/smb4.11_enable_smb1.patch"
# 【Sysctl自定义配置】内核参数微调
SYSCTL_CUSTOM_CONF="${PWD}/files/99-custom.conf"

# ==================================================================================
# 【阶段5.2】2020年9月30日添加的资源
# ==================================================================================
# 【声卡驱动模块】S905D的音频驱动配置
SND_MOD="${PWD}/files/s905d/snd-meson-gx"
# 【守护进程配置】可能的后台服务配置
DAEMON_JSON="${PWD}/files/s905d/daemon.json"

# ==================================================================================
# 【阶段5.3】2020年10月添加的资源
# ==================================================================================
# 【强制重启脚本】用于实现定时重启或远程重启
FORCE_REBOOT="${PWD}/files/s905d/reboot"
# 【网卡IRQ均衡脚本】优化网络中断处理，提高网络性能
BAL_ETH_IRQ="${PWD}/files/balethirq.pl"
# 【CPU频率修复脚本】修复CPU频率显示不准确问题
FIX_CPU_FREQ="${PWD}/files/fixcpufreq.pl"
# 【系统时间修复patch】修复系统时间不同步问题
SYSFIXTIME_PATCH="${PWD}/files/sysfixtime.patch"

# ==================================================================================
# 【阶段5.4】2020年11月28日添加的资源
# ==================================================================================
# 【OpenSSL引擎配置patch】修复某些SSL功能
SSL_CNF_PATCH="${PWD}/files/openssl_engine.patch"

# ==================================================================================
# 【阶段5.5】2020年12月12日添加的资源
# ==================================================================================
# 【IRQ均衡配置】网卡中断亲和性配置
BAL_CONFIG="${PWD}/files/s905d/balance_irq"
# 【CPU频率初始化脚本】启动时设置CPU频率策略
CPUFREQ_INIT="${PWD}/files/s905d/cpufreq"

# ==================================================================================
# 【阶段5.6】2021年3月2日修改的资源
# ==================================================================================
# 【U-Boot固件加载地址】FIP (Firmware Image Package) 方式
FIP_HOME="${PWD}/files/meson_btld/with_fip/s905d"
# 【带FIP的U-Boot】包含FIP的完整引导程序，用于从TF卡启动
UBOOT_WITH_FIP="${FIP_HOME}/n1-u-boot.bin.sd.bin"
# 【无FIP的U-Boot目录】纯U-Boot，用于EMMC写入
UBOOT_WITHOUT_FIP_HOME="${PWD}/files/meson_btld/without_fip"
UBOOT_WITHOUT_FIP="u-boot-n1.bin"

# ==================================================================================
# 【阶段5.7】2021年3月7日添加的资源
# ==================================================================================
# 【Shadowsocks依赖库】glibc版本的Shadowsocks库文件
SS_LIB="${PWD}/files/ss-glibc/lib-glibc.tar.xz"
# 【Shadowsocks可执行文件】ARMv8优化版（支持AES-NI加速）
SS_BIN="${PWD}/files/ss-glibc/armv8a_crypto/ss-bin-glibc.tar.xz"
# 【JQ工具】JSON处理命令行工具
JQ="${PWD}/files/jq"

# ==================================================================================
# 【阶段5.8】2021年3月30日添加的资源
# ==================================================================================
# 【Docker守护进程patch】修复Docker相关问题
DOCKERD_PATCH="${PWD}/files/dockerd.patch"

# ==================================================================================
# 【阶段5.9】2021年4月16日添加的资源
# ==================================================================================
# 【Armbian固件包】可能用于提取某些驱动或固件
FIRMWARE_TXZ="${PWD}/files/firmware_armbian.tar.xz"
# 【启动文件目录】Amlogic平台专用启动文件
BOOTFILES_HOME="${PWD}/files/bootfiles/amlogic"
# 【随机MAC生成脚本】生成符合规范的随机MAC地址
GET_RANDOM_MAC="${PWD}/files/get_random_mac.sh"

# ==================================================================================
# 【阶段5.10】2021年6月18日添加的资源
# ==================================================================================
# 【Docker说明文档】PDF格式的Docker使用说明
DOCKER_README="${PWD}/files/DockerReadme.pdf"

# ==================================================================================
# 【阶段5.11】2021年7月4日添加的资源
# ==================================================================================
# 【系统信息脚本】收集系统信息用于诊断
SYSINFO_SCRIPT="${PWD}/files/30-sysinfo.sh"

# ==================================================================================
# 【阶段5.12】2021年9月23日添加的资源
# ==================================================================================
# 【安装脚本】N1安装OpenWrt到EMMC的脚本
OPENWRT_INSTALL="${PWD}/files/openwrt-install-amlogic"
# 【更新脚本】N1在线更新OpenWrt的脚本
OPENWRT_UPDATE="${PWD}/files/openwrt-update-amlogic"
# 【内核更新脚本】单独更新内核的脚本
OPENWRT_KERNEL="${PWD}/files/openwrt-kernel"
# 【备份脚本】系统备份脚本
OPENWRT_BACKUP="${PWD}/files/openwrt-backup"

# ==================================================================================
# 【阶段5.13】2021年10月19日添加的资源
# ==================================================================================
# 【首次运行脚本】首次启动时执行的初始化脚本
FIRSTRUN_SCRIPT="${PWD}/files/first_run.sh"

# ==================================================================================
# 【阶段5.14】2021年10月20日添加的资源
# ==================================================================================
# 【N1专用U-Boot】Phicomm N1原厂U-Boot修改版
BTLD_BIN="${PWD}/files/s905d/u-boot-2015-phicomm-n1.bin"

# ==================================================================================
# 【阶段5.15】2021年10月24日添加的资源
# ==================================================================================
# 【设备型号数据库】用于自动识别Amlogic设备型号
MODEL_DB="${PWD}/files/amlogic_model_database.txt"
# 20211214 add
# 【7z解压工具】支持7z格式压缩文件处理
P7ZIP="${PWD}/files/7z"
# 20211217 add
# 【磁盘备份恢复工具】N1全盘备份/恢复工具
DDBR="${PWD}/files/openwrt-ddbr"
# 20220225 add
# 【SSH加密算法配置】指定允许的SSH加密套件（安全性优化）
SSH_CIPHERS="aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr,chacha20-poly1305@openssh.com"
# 【SSHHD加密算法配置】SSH服务端的加密算法配置
SSHD_CIPHERS="aes128-gcm@openssh.com,aes256-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr"
###########################################################################


# ==================================================================================
# 【阶段6】依赖检查与分区创建 - 镜像生成的前置工作
# ==================================================================================

# 【依赖检查】验证所有需要的文件和工具是否存在
# 函数：check_depends检查各种脚本和文件是否齐全
check_depends

# ==================================================================================
# 【分区参数定义】镜像分区布局配置
# ==================================================================================

# 【跳过扇区数】分区前保留4MB空间，用于引导程序
# 业务逻辑：U-Boot通常放在这个位置，避免覆盖
SKIP_MB=4
# 【BOOT分区大小】FAT32格式，256MB，存放内核和设备树
# 存放内容：zImage, uInitrd, *.dtb, uEnv.txt等启动文件
BOOT_MB=256
# 【ROOTFS分区大小】根文件系统分区，960MB
# 使用btrfs格式，支持压缩和快照
ROOTFS_MB=960
# 【总镜像大小】计算公式：跳过区 + BOOT区 + ROOTFS区
SIZE=$((SKIP_MB + BOOT_MB + ROOTFS_MB))

# ==================================================================================
# 【阶段7】镜像创建与分区操作
# ==================================================================================

# 【创建空镜像文件】生成指定大小的空.img文件
create_image "$TGT_IMG" "$SIZE"
# 【创建分区表】MBR分区表，创建两个分区
# 参数：设备名、分区表类型、跳过MB、BOOT大小、文件系统类型、分区起止位置
create_partition "$TGT_DEV" "msdos" "$SKIP_MB" "$BOOT_MB" "fat32" "0" "-1" "btrfs"
# 【格式化分区】创建文件系统
# 参数：设备名、分区号、文件系统类型、卷标
make_filesystem "$TGT_DEV" "B" "fat32" "BOOT" "R" "btrfs" "ROOTFS"
# 【挂载BOOT分区】将第一个分区挂载到TGT_BOOT目录
mount_fs "${TGT_DEV}p1" "${TGT_BOOT}" "vfat"
# 【挂载ROOTFS分区】将第二个分区挂载到TGT_ROOT目录
# 启用zstd压缩以节省空间，压缩级别由ZSTD_LEVEL变量指定
mount_fs "${TGT_DEV}p2" "${TGT_ROOT}" "btrfs" "compress=zstd:${ZSTD_LEVEL}"

# ==================================================================================
# 【阶段8】Btrfs子卷创建 - 启用Btrfs高级特性
# ==================================================================================

# 【创建/etc子卷】为/etc目录创建独立子卷，便于备份和恢复
# 业务逻辑：Btrfs子卷可以单独快照和恢复，etc包含重要配置
echo "创建 /etc 子卷 ..."
btrfs subvolume create $TGT_ROOT/etc


# ==================================================================================
# 【阶段9】提取文件系统内容 - 从tarball复制到镜像
# ==================================================================================

# 【提取OpenWrt根文件系统】将rootfs.tar.gz内容解压到ROOTFS分区
extract_rootfs_files
# 【提取Amlogic启动文件】将BOOT分区需要的文件复制到BOOT分区
extract_amlogic_boot_files


# ==================================================================================
# 【阶段10】配置引导参数 - 写入U-Boot引导配置
# ==================================================================================

echo "修改引导分区相关配置 ... "
cd $TGT_BOOT
# 【清理旧配置文件】删除旧的uEnv.ini（可能存在的遗留配置）
rm -f uEnv.ini
# 【写入新的uEnv.txt】U-Boot启动参数配置文件
# 关键参数说明：
#   LINUX=/zImage - 内核镜像文件名
#   INITRD=/uInitrd - 启动内存文件系统
#   FDT=/dtb/amlogic/meson-gxl-s905d-phicomm-n1.dtb - 设备树文件（重要！）
#   APPEND内核参数：
#     root=UUID=... - 根文件系统位置（通过UUID定位）
#     rootfstype=btrfs - 根文件系统类型
#     rootflags=compress=zstd:... - 根文件系统压缩参数
#     console=ttyAML0,115200n8 - 串口控制台参数
#     cgroup_enable=cpuset - 启用cgroup cpuset子系统
#     cgroup_memory=1 - 启用cgroup内存限制（Docker需要）
#     cgroup_enable=memory - 启用cgroup内存统计
#     swapaccount=1 - 启用swap账户统计
cat > uEnv.txt <<EOF
LINUX=/zImage
INITRD=/uInitrd

# 下列 dtb，用到哪个就把哪个的#删除，其它的则加上 # 在行首

# 用于 Phicomm N1
FDT=/dtb/amlogic/meson-gxl-s905d-phicomm-n1.dtb

# 用于 Phicomm N1 (thresh)
#FDT=/dtb/amlogic/meson-gxl-s905d-phicomm-n1-thresh.dtb

APPEND=root=UUID=${ROOTFS_UUID} rootfstype=btrfs rootflags=compress=zstd:${ZSTD_LEVEL} console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
EOF

echo "uEnv.txt -->"
echo "==============================================================================="
cat uEnv.txt
echo "==============================================================================="
echo


# ==================================================================================
# 【阶段11】根文件系统定制 - 修改系统配置和应用
# ==================================================================================

echo "修改根文件系统相关配置 ... "
cd $TGT_ROOT
# 【复制补充文件】将files目录下的配置文件复制到对应位置
copy_supplement_files
# 【提取glibc程序】某些需要glibc的二进制程序（Shadowsocks等）
extract_glibc_programs
# 【调整Docker配置】配置Docker运行时环境
adjust_docker_config
# 【调整OpenSSL配置】优化SSL/TLS参数
adjust_openssl_config
# 【调整Getty配置】串口登录终端配置
adjust_getty_config
# 【调整Samba配置】文件共享服务配置
adjust_samba_config
# 【调整OpenSSH配置】SSH服务加密套件配置（安全加固）
adjust_openssh_config
# 【调整OpenClash配置】代理软件配置
adjust_openclash_config
# 【使用Xray替换V2ray】将V2ray核心替换为Xray核心
use_xrayplug_replace_v2rayplug
# 【创建fstab配置】文件系统挂载表
create_fstab_config
# 【调整MosDNS配置】（已注释）DNS转发配置
#adjust_mosdns_config
# 【修补管理页面】修改LuCI状态页面
patch_admin_status_index_html
# 【调整内核环境】内核模块加载和参数配置
adjust_kernel_env
# 【复制U-Boot到文件系统】在rootfs中也保留一份U-Boot备份
copy_uboot_to_fs
# 【写入发布信息】生成系统版本信息文件
write_release_info
# 【写入欢迎横幅】终端登录时的欢迎信息
write_banner 
# 【配置首次运行】首次启动时的初始化任务
config_first_run
# 【创建快照】为/etc子卷创建初始快照
create_snapshot "etc-000"
# 【写入U-Boot到磁盘】将U-Boot写入镜像的指定位置
write_uboot_to_disk
# 【清理工作环境】卸载分区，清理临时文件
clean_work_env
# 【移动镜像到输出目录】将生成的IMG文件移到最终输出位置
mv ${TGT_IMG} ${OUTPUT_DIR} && sync
echo "镜像已生成! 存放在 ${OUTPUT_DIR} 下面!"
echo "========================== end $0 ================================"
echo

# ==================================================================================
# 【脚本结束】本脚本完成以下工作：
#   1. 加载环境和公共函数库
#   2. 配置内核版本和来源
#   3. 定义所有需要注入的补丁和脚本路径
#   4. 创建1.2GB镜像文件并分区（4MB skip + 256MB BOOT + 960MB ROOTFS）
#   5. 格式化分区为FAT32(BOOT)和btrfs(ROOTFS)
#   6. 提取OpenWrt rootfs和Amlogic启动文件到对应分区
#   7. 配置uEnv.txt引导参数（指定DTB文件）
#   8. 执行一系列系统定制（Docker/SSH/Samba等）
#   9. 写入U-Boot引导程序
#   10. 输出最终的.img.xz压缩文件
# ==================================================================================
