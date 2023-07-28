#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

update_shell_url=""
SoraBot_url="https://github.com/netsora/SoraBot.git"
WORK_DIR="/data"
TMP_DIR="$(mktemp -d)"
python_v="python3.10"
sh_ver="1.1.3"
ghproxy="https://ghproxy.com/"
mirror_url="https://pypi.org/simple"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo -i${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}

#检查系统
check_sys() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif grep -q -E -i "debian" /etc/issue; then
        release="debian" 
    elif grep -q -E -i "ubuntu" /etc/issue; then
        release="ubuntu"
    elif grep -q -E -i "centos|red hat|redhat" /etc/issue; then
        release="centos"
    elif grep -q -E -i "Arch|Manjaro" /etc/issue; then
        release="archlinux"
    elif grep -q -E -i "debian" /proc/version; then
        release="debian"
    elif grep -q -E -i "ubuntu" /proc/version; then
        release="ubuntu"
    elif grep -q -E -i "centos|red hat|redhat" /proc/version; then
        release="centos"
    else
        echo -e "SoraBot 暂不支持该Linux发行版" && exit 1
    fi
    bit=$(uname -m)
}

check_installed_SoraBot_status() {
  [[ ! -e "${WORK_DIR}/SoraBot/bot.py" ]] && echo -e "${Error} SoraBot 没有安装，请检查 !" && exit 1
}

check_installed_cqhttp_status() {
  [[ ! -e "${WORK_DIR}/go-cqhttp/go-cqhttp" ]] && echo -e "${Error} go-cqhttp 没有安装，请检查 !" && exit 1
}

check_pid_SoraBot() {
  #PID=$(ps -ef | grep "sergate" | grep -v grep | grep -v ".sh" | grep -v "init.d" | grep -v "service" | awk '{print $2}')
  PID=$(pgrep -f "bot.py")
}

check_pid_cqhttp() {
  #PID=$(ps -ef | grep "sergate" | grep -v grep | grep -v ".sh" | grep -v "init.d" | grep -v "service" | awk '{print $2}')
  PID=$(pgrep -f "go-cqhttp")
}

Set_pip_Mirror() {
  echo -e "${Info} 请输入要选择的pip下载源，默认使用官方源，中国大陆建议选择清华源
  ${Green_font_prefix} 1.${Font_color_suffix} 默认
  ${Green_font_prefix} 2.${Font_color_suffix} 清华源"
  read -erp "请输入数字 [1-2], 默认为 1:" mirror_num
  [[ -z "${mirror_num}" ]] && mirror_num=1
  [[ ${mirror_num} == 2 ]] && mirror_url="https://pypi.tuna.tsinghua.edu.cn/simple"
}

Set_ghproxy() {
  echo -e "${Info} 是否使用 ghproxy 代理git相关的下载？(中国大陆建议使用)"
  read -erp "请选择 [y/n], 默认为 y:" ghproxy_check
  [[ -z "${ghproxy_check}" ]] && ghproxy_check='y'
  [[ ${ghproxy_check} == 'n' ]] && ghproxy=""
}

Set_work_dir() {
  echo -e "${Info} 使用自定义工作目录?"
  echo -e "${Info} 该目录下对应的文件夹将会被用于存放 SoraBot 和 go-cqhttp 的相关文件"
  read -erp "留空使用默认目录, 默认为 (/data):" work_dir_check
  [[ -z "${work_dir_check}" ]] && WORK_DIR='/data'
  [[ -n ${work_dir_check} ]] && WORK_DIR=${work_dir_check}
}

Installation_openssl(){

wget --no-check-certificate https://www.openssl.org/source/openssl-1.1.1u.tar.gz -O ${TMP_DIR}/openssl-1.1.1u.tar.gz && \
  tar -zxf ${TMP_DIR}/openssl-1.1.1u.tar.gz -C ${TMP_DIR}/ && \
  cd ${TMP_DIR}/openssl-1.1.1u && \
  ./config --prefix=/data/openssl-1.1.1u && \
  make && make install > /dev/null 

}


Installation_dependency() {
    if [[ ${release} == "centos" ]]; then
        #yum -y update > /dev/null
        yum install -y git fontconfig mkfontscale epel-release wget vim curl zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make libffi-devel > /dev/null
        if  ! which ${python_v}; then
	    Installation_openssl
            wget https://mirrors.huaweicloud.com/python/3.10.12/Python-3.10.12.tgz -O ${TMP_DIR}/Python-3.10.12.tgz && \
                tar -zxf ${TMP_DIR}/Python-3.10.12.tgz -C ${TMP_DIR}/ &&\
                cd ${TMP_DIR}/Python-3.10.12 && \
                ./configure --prefix=/data/${python_v} --with-openssl=/data/openssl-1.1.1u --with-openssl-rpath=auto --with-ensurepip=install && \
                make -j $(cat /proc/cpuinfo |grep "processor"|wc -l) && \
                make altinstall > /dev/null
                ln -s /data/${python_v}/bin/* /usr/bin
            python_v="python3.10"
        fi
	#${python_v} <`curl -s -L https://bootstrap.pypa.io/get-pip.py` || echo -e "${Tip} pip 安装出错..."
        rpm -v --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro > /dev/null
        rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm > /dev/null
    elif [[ ${release} == "debian" ]]; then
        #apt-get update > /dev/null
        apt-get install -y wget ttf-wqy-zenhei xfonts-intl-chinese wqy* build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev > /dev/null
        if  ! which ${python_v};then
	    Installation_openssl
            wget https://mirrors.huaweicloud.com/python/3.10.12/Python-3.10.12.tgz -O ${TMP_DIR}/Python-3.10.12.tgz && \
                tar -zxf ${TMP_DIR}/Python-3.10.12.tgz -C ${TMP_DIR}/ &&\
                cd ${TMP_DIR}/Python-3.10.12 && \
                ./configure --prefix=/data/${python_v} --with-ensurepip=install && \
                make -j $(cat /proc/cpuinfo |grep "processor"|wc -l) && \
                make altinstall > /dev/null
		ln -s /data/${python_v}/bin/* /usr/bin
             pythone_v="python3.10"    
        fi
        apt-get install -y \
            vim \
            wget \
            git \
            libgl1 \
            libglib2.0-0 \
            libnss3 \
            libatk1.0-0 \
            libatk-bridge2.0-0 \
            libcups2 \
            libxkbcommon0 \
            libxcomposite1 \
            libxrandr2 \
            libgbm1 \
            libgtk-3-0 \
            libasound2 > /dev/null
        #${python_v} <`curl -s -L https://bootstrap.pypa.io/get-pip.py` || echo -e "${Tip} pip 安装出错..."
    elif [[ ${release} == "ubuntu" ]]; then
        #apt-get update > /dev/null
        apt-get install -y software-properties-common ttf-wqy-zenhei ttf-wqy-microhei fonts-arphic-ukai fonts-arphic-uming > /dev/null
        fc-cache -f -v
        echo -e "\n" | add-apt-repository ppa:deadsnakes/ppa
        if  ! which python3.10;then
            apt-get install -y python3.10-full > /dev/null
	    python_v="python3.10"
            
        fi
        apt-get install -y \
            vim \
            wget \
            git \
            libgl1 \
            libglib2.0-0 \
            libnss3 \
            libatk1.0-0 \
            libatk-bridge2.0-0 \
            libcups2 \
            libxkbcommon0 \
            libxcomposite1 \
            libxrandr2 \
            libgbm1 \
            libgtk-3-0 \
            libasound2 > /dev/null
        #${python_v} <`curl -s -L https://bootstrap.pypa.io/get-pip.py` || echo -e "${Tip} pip 安装出错..."
    elif [[ ${release} == "archlinux" ]]; then
        pacman -Sy python python-pip unzip --noconfirm
    fi
    [[ ! -e /usr/bin/python3 ]] && ln -s /usr/bin/${python_v} /usr/bin/python3
}

check_arch() {
  get_arch=$(arch)
  if [[ ${get_arch} == "x86_64" ]]; then 
    arch="amd64"
  elif [[ ${get_arch} == "aarch64" ]]; then
    arch="arm64"
  else
    echo -e "${Error} go-cqhttp 不支持该内核版本(${get_arch})..." && exit 1
  fi
}

Download_SoraBot() {
    cd "${TMP_DIR}" || exit 1
    echo -e "${Info} 开始下载最新版 SoraBot ..."
    git clone "${ghproxy}${SoraBot_url}" -b master || (echo -e "${Error} SoraBot 下载失败 !" && exit 1)
    echo -e "${Info} 开始下载最新版 go-cqhttp ..."
    gocq_version=$(wget -qO- -t1 -T2 "https://api.github.com/repos/Mrs4s/go-cqhttp/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
    wget -qO- "${ghproxy}https://github.com/Mrs4s/go-cqhttp/releases/download/${gocq_version}/go-cqhttp_$(uname -s)_${arch}.tar.gz" -O go-cqhttp.tar.gz || (echo -e "${Error} go-cqhttp 下载失败 !" && exit 1)
    cd "${WORK_DIR}" || exit 1
    mv "${TMP_DIR}/SoraBot" ./
    mkdir -p "go-cqhttp"
    tar -zxf "${TMP_DIR}/go-cqhttp.tar.gz" -C ./go-cqhttp/
}

Set_config_admin() {
    echo -e "${Info} 请输入频道信息:"
    read -erp "QQ频道开发者ID:" BotAppID
    read -erp "QQ频道机器人令牌:" BotToken
    read -erp "QQ频道机器人密钥:" BotSecret
    read -erp "tg机器人token(如果不使用tg可以为空，请直接回车):" tg_token 
    cd ${WORK_DIR}/SoraBot && \
      sed -i "s/\"id\".*/\"id\": \"$BotAppID\",/g" .env  
      sed -i "s/\"token\".*/\"token\": \"$BotToken\",/g" .env 
      sed -i "s/\"secret\".*/\"secret\": \"$BotSecret\",/g" .env || \
      echo -e "${Error} 配置文件不存在！请检查SoraBot是否安装正确!" && \
    echo -e "${info} 设置成功!"

   if [[ -n "$tg_token" ]] && [[ $tg_token != "" ]]  ;then
      sed -i "s/telegram_bots.*/telegram_bots = [{${tg_token}}]/g" .env 

   else 
      # 注释掉TG模块
      sed -i "/TG_Adapter/s/^/#/g" bot.py

   fi
}

Set_config_bot() {
    echo -e "${Info} 请输入Bot QQ账号:[QQ]"
    read -erp "Bot QQ:" bot_qq
    [[ -z "$bot_qq" ]] && bot_qq=""
    cd ${WORK_DIR}/go-cqhttp && sed -i "s/uin:.*/uin: $bot_qq/g" config.yml || echo -e "${Error} 配置文件不存在！请检查go-cqhttp是否安装正确!"
    echo -e "${info} 设置成功!Bot QQ: ${bot_qq}"
}

Set_config() {
    if [[ -e "${WORK_DIR}/go-cqhttp/config.yml" ]]; then
        echo -e "${info} go-cqhttp 配置文件已存在，跳过生成"
    else
        cd ${WORK_DIR}/go-cqhttp && echo -e "3\n" | ./go-cqhttp > /dev/null 2>&1
    fi
    Set_config_bot
    Set_config_admin
}

Start_SoraBot() {
    check_installed_SoraBot_status
    check_pid_SoraBot
    ${python_v} -m pip list | grep poetry > /dev/null 2>&1 || (echo "${Tip} 虚拟环境未安装,开始安装虚拟环境..." && Set_dependency)
    [[ -n ${PID} ]] && echo -e "${Error} SoraBot 正在运行，请检查 !" && exit 1
    cd ${WORK_DIR}/SoraBot
    nohup ${python_v} -m poetry run python bot.py >> SoraBot.log 2>&1 &
    echo -e "${Info} SoraBot 开始运行..."
}

Start_SoraBot_Old() {
    check_installed_SoraBot_status
    check_pid_SoraBot
    [[ -n ${PID} ]] && echo -e "${Error} SoraBot 正在运行，请检查 !" && exit 1
    cd ${WORK_DIR}/SoraBot
    nohup ${python_v} bot.py >> SoraBot.log 2>&1 &
    echo -e "${Info} SoraBot 开始运行..."
}

Stop_SoraBot() {
    check_installed_SoraBot_status
    check_pid_SoraBot
    [[ -z ${PID} ]] && echo -e "${Error} SoraBot 没有运行，请检查 !" && exit 1
    kill -9 ${PID}
    echo -e "${Info} SoraBot 已停止运行..."
}

Restart_SoraBot() {
    Stop_SoraBot
    Start_SoraBot
}

View_SoraBot_log() {
    tail -f -n 100 ${WORK_DIR}/SoraBot/SoraBot.log
}

Set_config_SoraBot() {
    vim ${WORK_DIR}/SoraBot/configs/config.yaml
}

Start_cqhttp() {
    check_installed_cqhttp_status
    check_pid_cqhttp
    [[ -n ${PID} ]] && echo -e "${Error} go-cqhttp 正在运行，请检查 !" && exit 1
    cd ${WORK_DIR}/go-cqhttp
    nohup ./go-cqhttp -faststart >> go-cqhttp.log 2>&1 &
    echo -e "${Info} go-cqhttp 开始运行..."
    echo -e "${info} 请扫描二维码登录 bot，bot 账号登录完成后，使用Ctrl + C退出 !"
    sleep 2
}

Stop_cqhttp() {
    check_installed_cqhttp_status
    check_pid_cqhttp
    [[ -z ${PID} ]] && echo -e "${Error} cqhttp 没有运行，请检查 !" && exit 1
    kill -9 ${PID}
    echo -e "${Info} go-cqhttp 停止运行..."
}

Restart_cqhttp() {
    Stop_cqhttp
    Start_cqhttp
}

View_cqhttp_log() {
    tail -f -n 100 ${WORK_DIR}/go-cqhttp/go-cqhttp.log
}

Set_config_cqhttp() {
    vim ${WORK_DIR}/go-cqhttp/config.yml
}


Set_config_SoraBot() {
    vim ${WORK_DIR}/SoraBot/configs/config.yaml
}

Exit_cqhttp() {
    cd ${WORK_DIR}/go-cqhttp
    rm -f session.token
    echo -e "${Info} go-cqhttp 账号已退出..."
    Stop_cqhttp
    sleep 3
    menu_cqhttp
}

Set_dependency() {
    cd ${WORK_DIR}/SoraBot
    cat << EOF >> pyproject.toml
      [[tool.poetry.source]]
      name = "aliyun"
      url = "http://mirrors.aliyun.com/pypi/simple"
      default = true
EOF
    ${python_v} -m pip install --ignore-installed poetry -i ${mirror_url} --trusted-host ${mirror_url}
    ${python_v} -m poetry install
    #${python_v} -m playwright install chromium
}

Uninstall_All() {
  echo -e "${Tip} 是否完全卸载 SoraBot 和 go-cqhttp？(此操作不可逆)"
  read -erp "请选择 [y/n], 默认为 n:" uninstall_check
  [[ -z "${uninstall_check}" ]] && uninstall_check='n'
  if [[ ${uninstall_check} == 'y' ]]; then
    cd ${WORK_DIR}
    check_pid_SoraBot
    [[ -z ${PID} ]] || kill -9 ${PID}
    echo -e "${Info} 开始卸载 SoraBot..."
    rm -rf SoraBot || echo -e "${Error} SoraBot 卸载失败！"
    check_pid_cqhttp
    [[ -z ${PID} ]] || kill -9 ${PID}
    echo -e "${Info} 开始卸载 go-cqhttp..."
    rm -rf go-cqhttp || echo -e "${Error} go-cqhttp 卸载失败！"
    echo -e "${Info} 感谢使用真寻bot，期待于你的下次相会！"
  fi
  echo -e "${Info} 操作已取消..." && menu_SoraBot
}

Install_SoraBot() {
    check_root
    [[ -e "${WORK_DIR}/SoraBot/bot.py" ]] && echo -e "${Error} 检测到 SoraBot 已安装 !" && exit 1
    startTime=`date +%s`
    Set_ghproxy
    echo -e "${Info} 开始检查系统..."
    check_arch
    check_sys
    echo -e "${Info} 开始安装/配置 依赖..."
    Installation_dependency
    echo -e "${Info} 开始下载/安装..."
    Download_SoraBot
    echo -e "${Info} 开始设置 用户配置..."
    Set_config
    echo -e "${Info} 开始配置 SoraBot 环境..."
    Set_pip_Mirror
    Set_dependency
   # 设置主机字体 仅centos
   # if [[ ${release} == "centos" ]]; then
   #     echo -e "${Info} CentOS 中文字体设置..."
   #     sudo mkdir -p /usr/share/fonts/chinese
   #     sudo cp -r ${WORK_DIR}/SoraBot/resources/font /usr/share/fonts/chinese
   #     cd /usr/share/fonts/chinese && mkfontscale
   # fi
    endTime=`date +%s`
    ((outTime=($endTime-$startTime)))
    echo -e "${Info} 安装用时 ${outTime} s ..."
    echo -e "${Info} 开始运行 SoraBot..."
    Start_SoraBot
    echo -e "${Info} 开始运行 go-cqhttp..."
    Start_cqhttp
    View_cqhttp_log
}

Update_Shell(){
    echo -e "${Info} 开始更新install.sh"
    bak_dir_name="sh_bak/"
    bak_file_name="${bak_dir_name}install.`date +%Y%m%d%H%M%s`.sh"
    if [[ ! -d ${bak_dir_name} ]]; then
        sudo mkdir -p ${bak_dir_name}
        echo -e "${Info} 创建备份文件夹${bak_dir_name}"
    fi
    wget ${update_shell_url} -O install.sh.new
    sudo cp -f install.sh ${bak_file_name}
    echo -e "${Info} 备份原install.sh为${bak_file_name}"
    sudo mv -f install.sh.new install.sh
    echo -e "${Info} install.sh更新完成，请重新启动"
    exit 0
}

menu_cqhttp() {
  echo && echo -e "  go-cqhttp 一键安装管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  -- Sakura | github.com/AkashiCoin --
 ${Green_font_prefix} 0.${Font_color_suffix} 升级脚本
 ————————————
 ${Green_font_prefix} 1.${Font_color_suffix} 安装 SoraBot + go-cqhttp
————————————
 ${Green_font_prefix} 2.${Font_color_suffix} 启动 go-cqhttp
 ${Green_font_prefix} 3.${Font_color_suffix} 停止 go-cqhttp
 ${Green_font_prefix} 4.${Font_color_suffix} 重启 go-cqhttp
————————————
 ${Green_font_prefix} 5.${Font_color_suffix} 设置 bot QQ账号
 ${Green_font_prefix} 6.${Font_color_suffix} 修改 go-cqhttp 配置文件
 ${Green_font_prefix} 7.${Font_color_suffix} 查看 go-cqhttp 日志
————————————
 ${Green_font_prefix} 8.${Font_color_suffix} 退出 go-cqhttp 账号
 ${Green_font_prefix}10.${Font_color_suffix} 切换为 SoraBot 菜单" && echo
  if [[ -e "${WORK_DIR}/go-cqhttp/go-cqhttp" ]]; then
    check_pid_cqhttp
    if [[ -n "${PID}" ]]; then
      echo -e " 当前状态: go-cqhttp ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
    else
      echo -e " 当前状态: go-cqhttp ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
    fi
  else
    if [[ -e "${file}/go-cqhttp/go-cqhttp" ]]; then
      check_pid_cqhttp
      if [[ -n "${PID}" ]]; then
        echo -e " 当前状态: go-cqhttp ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
      else
        echo -e " 当前状态: go-cqhttp ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
      fi
    else
      echo -e " 当前状态: go-cqhttp ${Red_font_prefix}未安装${Font_color_suffix}"
    fi
  fi
  echo
  read -erp " 请输入数字 [0-10]:" num
  case "$num" in
  0)
    Update_Shell
    ;;
  1)
    Install_SoraBot
    ;;
  2)
    Start_cqhttp
    ;;
  3)
    Stop_cqhttp
    ;;
  4)
    Restart_cqhttp
    ;;
  5)
    Set_config_bot
    ;;
  6)
    Set_config_cqhttp
    ;;
  7)
    View_cqhttp_log
    ;;  
  8)
    Exit_cqhttp
    ;;
  10)
    menu_SoraBot
    ;;
  *)
    echo "请输入正确数字 [0-10]"
    ;;
  esac
}

menu_SoraBot() {
  echo && echo -e "  SoraBot 一键安装管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  -- Sakura | github.com/AkashiCoin --
 ${Green_font_prefix} 0.${Font_color_suffix} 升级脚本
 ————————————
 ${Green_font_prefix} 1.${Font_color_suffix} 安装 SoraBot + go-cqhttp
————————————
 ${Green_font_prefix} 2.${Font_color_suffix} 启动 SoraBot
 ${Green_font_prefix} 3.${Font_color_suffix} 停止 SoraBot
 ${Green_font_prefix} 4.${Font_color_suffix} 重启 SoraBot
————————————
 ${Green_font_prefix} 5.${Font_color_suffix} 设置 管理员账号
 ${Green_font_prefix} 6.${Font_color_suffix} 修改 SoraBot 配置文件
 ${Green_font_prefix} 7.${Font_color_suffix} 查看 SoraBot 日志
————————————
 ${Green_font_prefix} 8.${Font_color_suffix} 卸载 SoraBot + go-cqhttp
 ${Green_font_prefix} 9.${Font_color_suffix} 旧版启动 SoraBot
 ${Green_font_prefix}10.${Font_color_suffix} 切换为 go-cqhttp 菜单" && echo
  if [[ -e "${WORK_DIR}/SoraBot/bot.py" ]]; then
    check_pid_SoraBot
    if [[ -n "${PID}" ]]; then
      echo -e " 当前状态: SoraBot ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
    else
      echo -e " 当前状态: SoraBot ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
    fi
  else
    if [[ -e "${file}/SoraBot/bot.py" ]]; then
      check_pid_SoraBot
      if [[ -n "${PID}" ]]; then
        echo -e " 当前状态: SoraBot ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
      else
        echo -e " 当前状态: SoraBot ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
      fi
    else
      echo -e " 当前状态: SoraBot ${Red_font_prefix}未安装${Font_color_suffix}"
    fi
  fi
  echo
  read -erp " 请输入数字 [0-10]:" num
  case "$num" in
  0)
    Update_Shell
    ;;
  1)
    Install_SoraBot
    ;;
  2)
    Start_SoraBot
    ;;
  3)
    Stop_SoraBot
    ;;
  4)
    Restart_SoraBot
    ;;
  5)
    Set_config_admin
    ;;
  6)
    Set_config_SoraBot
    ;;
  7)
    View_SoraBot_log
    ;;
  8)
    Uninstall_All
    ;;
  9)
    Start_SoraBot_Old
    ;;
  10)
    menu_cqhttp
    ;;
  *)
    echo "请输入正确数字 [0-10]"
    ;;
  esac
}

Set_work_dir
menu_SoraBot
