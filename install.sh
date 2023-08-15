#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

update_shell_url="https://raw.githubusercontent.com/TKINGNAMe/Sorabot-deploy/master/install.sh"
SoraBot_url="https://github.com/netsora/SoraBot.git"
WORK_DIR="/data"
TMP_DIR="$(mktemp -d)"
python_v="python3.10"
sh_ver="1.1.0"
ghproxy="https://ghproxy.com/"
mirror_url="https://pypi.tuna.tsinghua.edu.cn/simple"

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
  echo -e "${Info} 请输入要选择的pip下载源，默认使用清华源，中国大陆建议选择清华源
  ${Green_font_prefix} 1.${Font_color_suffix} 清华源
  ${Green_font_prefix} 2.${Font_color_suffix} 官方源"
  read -erp "请输入数字 [1-2], 默认为 1:" mirror_num
  [[ -z "${mirror_num}" ]] && mirror_num=1
  [[ ${mirror_num} == 2 ]] && mirror_url="https://pypi.org/simple"
  ${python_v} -m pip config set global.index-url ${mirror_url}

}

Set_ghproxy() {
  echo -e "${Info} 是否使用 ghproxy 代理git相关的下载？(中国大陆建议使用)"
  read -erp "请选择 [y/n], 默认为 y:" ghproxy_check
  [[ -z "${ghproxy_check}" ]] && ghproxy_check='y'
  [[ ${ghproxy_check} == 'n' ]] && ghproxy=""
}

Set_work_dir() {
  echo -e "${Info} 使用自定义工作目录?"
  echo -e "${Info} 该目录下对应的文件夹将会被用于存放 SoraBot 的相关文件"
  read -erp "留空使用默认目录, 默认为 (/data):" work_dir_check
  [[ -z "${work_dir_check}" ]] && WORK_DIR='/data'
  [[ -n ${work_dir_check} ]] && WORK_DIR=${work_dir_check}
  [[ -d $WORK_DIR ]] || mkdir $WORK_DIR
}

Installation_openssl(){
echo "安装python需要高版本的openssl 正在为您一键安装ing..."
wget --no-check-certificate https://www.openssl.org/source/openssl-1.1.1u.tar.gz -O ${TMP_DIR}/openssl-1.1.1u.tar.gz && \
  tar -zxf ${TMP_DIR}/openssl-1.1.1u.tar.gz -C ${TMP_DIR}/ && \
  cd ${TMP_DIR}/openssl-1.1.1u && \
  ./config --prefix=${WORK_DIR}/openssl-1.1.1u && \
  echo "开始安装 openssl-1.1.1u 安装目录为{WORK_DIR}/openssl-1.1.1u"
  make && make install > /dev/null && echo "----openssl安装成功----"

}


Installation_dependency() {
    if [[ ${release} == "centos" ]]; then
        yum install -y git fontconfig mkfontscale epel-release perl wget vim curl zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make libffi-devel || \
        yum install --allowerasing -y git fontconfig mkfontscale epel-release perl wget vim curl zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make libffi-devel
        if  ! which ${python_v}; then
	      Installation_openssl
            wget https://mirrors.huaweicloud.com/python/3.10.12/Python-3.10.12.tgz -O ${TMP_DIR}/Python-3.10.12.tgz && \
                tar -zxf ${TMP_DIR}/Python-3.10.12.tgz -C ${TMP_DIR}/ &&\
                cd ${TMP_DIR}/Python-3.10.12 && \
                ./configure --prefix=${WORK_DIR}/${python_v} --with-openssl=${WORK_DIR}/openssl-1.1.1u --with-openssl-rpath=auto --with-ensurepip=install && \
                make -j $(cat /proc/cpuinfo |grep "processor"|wc -l) && \
                make altinstall > /dev/null
                ln -s ${WORK_DIR}/${python_v}/bin/* /usr/bin
        fi

        rpm -v --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro > /dev/null
        rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm > /dev/null
    elif [[ ${release} == "debian" ]]; then
        apt-get install -y wget ttf-wqy-zenhei xfonts-intl-chinese wqy* build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev > /dev/null
        if  ! which ${python_v};then
	      Installation_openssl
            wget https://mirrors.huaweicloud.com/python/3.10.12/Python-3.10.12.tgz -O ${TMP_DIR}/Python-3.10.12.tgz && \
                tar -zxf ${TMP_DIR}/Python-3.10.12.tgz -C ${TMP_DIR}/ &&\
                cd ${TMP_DIR}/Python-3.10.12 && \
                ./configure --prefix=${WORK_DIR}/${python_v} --with-ensurepip=install && \
                make -j $(cat /proc/cpuinfo |grep "processor"|wc -l) && \
                make altinstall > /dev/null
		ln -s ${WORK_DIR}/${python_v}/bin/* /usr/bin
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

    elif [[ ${release} == "ubuntu" ]]; then
        apt-get install -y software-properties-common ttf-wqy-zenhei ttf-wqy-microhei fonts-arphic-ukai fonts-arphic-uming > /dev/null
        fc-cache -f -v
        echo -e "\n" | add-apt-repository ppa:deadsnakes/ppa
        if  ! which python3.10;then
            apt-get install -y python3.10-full > /dev/null
            
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
    echo -e "${Error} 不支持该内核版本(${get_arch})..." && exit 1
  fi
}

Download_SoraBot() {
    cd "${TMP_DIR}" || exit 1
    echo -e "${Info} 开始下载最新版 SoraBot ..."
    git clone "${ghproxy}${SoraBot_url}" -b master || (echo -e "${Error} SoraBot 下载失败 !" && exit 1)
    # echo -e "${Info} 开始下载最新版 go-cqhttp ..."
    # gocq_version=$(wget -qO- -t1 -T2 "https://api.github.com/repos/Mrs4s/go-cqhttp/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
    # wget -qO- "${ghproxy}https://github.com/Mrs4s/go-cqhttp/releases/download/${gocq_version}/go-cqhttp_$(uname -s)_${arch}.tar.gz" -O go-cqhttp.tar.gz || (echo -e "${Error} go-cqhttp 下载失败 !" && exit 1)
    cd "${WORK_DIR}" || exit 1
    mv "${TMP_DIR}/SoraBot" ./
    # mkdir -p "go-cqhttp"
    # tar -zxf "${TMP_DIR}/go-cqhttp.tar.gz" -C ./go-cqhttp/
}

Set_config_env() {
    echo -e "${Info} 请输入频道信息:"
    read -erp "QQ频道BotAppID(开发者ID):" BotAppID
    read -erp "QQ频道机器人令牌:" BotToken
    read -erp "QQ频道机器人密钥:" BotSecret
    read -erp "tg机器人token(如果不使用tg可以为空，请直接回车):" tg_token 
    cd ${WORK_DIR}/SoraBot && \
      sed -i "/^[[:space:]]/s/\"id\".*/\"id\": \"$BotAppID\",/g" .env  
      sed -i "/^[[:space:]]/s/\"token\".*/\"token\": \"$BotToken\",/g" .env 
      sed -i "/^[[:space:]]/s/\"secret\".*/\"secret\": \"$BotSecret\",/g" .env || \
      echo -e "${Error} 配置文件不存在！请检查SoraBot是否安装正确!" && \
    echo -e "${info} 设置成功!"

   if [[ -n "$tg_token" ]] && [[ $tg_token != "" ]]  ;then
      sed -i "s/telegram_bots.*/telegram_bots = [{${tg_token}}]/g" .env 
      read -erp "tg的代理proxy网址(你已经设置了tg机器人,请使用魔法!):" tg_proxy
      sed -i "/^PROXY/s/PROXY=.*/PROXY=\"$tg_proxy\"/" .env.prod

   else 
      # 注释掉TG模块
      sed -i "/TG_Adapter/s/^/#/g" bot.py

   fi
}

Set_config_envprod(){
cd ${WORK_DIR}/SoraBot || echo -e ${Error} "请确认是否正确安装了SoraBot"
echo -e ${Info} "-------------------------关于管理账号的解释-------------------------"
echo -e ${Info} "林汐没有使用 Nonebot2 所提供的 SUPERUSER，而是改为了 Bot管理员 和 Bot协助者"
echo -e ${Info} "-----WARNING----------请注意所有的ID都必须保持唯一----------WARNING-----"
echo -e ${Info} "启动后，林汐会自动为他们注册账号及密码${Red_font_prefix}(初始密码可以在启动后的日志中查看)"
echo -e ${Info} "下面开始设置你的管理员账号和协助者账号${Red_font_prefix}(管理员账号只能设置一个!!权限最大)"
echo -e ${Info} "-------------------------关于管理账号的解释-------------------------"
echo ""

read -erp "请输入Bot管理员ID(自定义,注意前后不能有空格)" bot_admin

sed -i "/BOT_ADMIN/s/BOT_ADMIN.*/BOT_ADMIN=[\"$bot_admin\"]/" .env.prod && echo "设置成功"

read -erp "请输入Bot协助者ID(自定义,多个账号时使用 '/' 分隔)" bot_helper
bot_helper_list=(`echo $bot_helper | awk -F '/' '{for (i=1;i<=NF;i++){print $i} }'`)

for i in ${bot_helper_list[@]}
do
list+=\"$i\",
done

sed -i "/BOT_HELPER/s/BOT_HELPER.*/BOT_HELPER=[$list]/" .env.prod && echo "设置成功"



}


Set_config_bot() {
    echo -e "${Info} 请输入Bot QQ账号:[QQ]"
    read -erp "Bot QQ:" bot_qq
    [[ -z "$bot_qq" ]] && bot_qq=""
    cd ${WORK_DIR}/go-cqhttp && sed -i "s/uin:.*/uin: $bot_qq/g" config.yml || echo -e "${Error} 配置文件不存在！请检查go-cqhttp是否安装正确!"
    echo -e "${info} 设置成功!Bot QQ: ${bot_qq}"
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
echo " 输入需要修改的配置(输入阿拉伯数字即可):"
echo -e "${Green_font_prefix} 0.${Font_color_suffix} 返回上一级 总控制菜单"
echo -e "${Green_font_prefix} 1.${Font_color_suffix} 修改插件配置 config.yaml"
echo -e "${Green_font_prefix} 2.${Font_color_suffix} 修改适配器配置 .env"
echo -e "${Green_font_prefix} 3.${Font_color_suffix} 修改Bot配置 .env.prod"
read -erp " 请选择:" config_num
if [ $config_num == '1' ];then
    vim ${WORK_DIR}/SoraBot/data/config/config.yaml
elif [ $config_num == '2' ];then
    vim ${WORK_DIR}/SoraBot/.env
elif [ $config_num == '3' ];then
    vim ${WORK_DIR}/SoraBot/.env.prod
elif [ $config_num == '0' ];then
    menu_SoraBot
else 
    echo -e ${Error} "暂不支持其他配置，请重新输入哦!"
fi
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


    ${python_v} -m pip install --ignore-installed poetry
    ${python_v} -m poetry install
    #${python_v} -m playwright install chromium
}

Uninstall_All() {
  echo -e "${Tip} 是否完全卸载 SoraBot python openssl ？(此操作不可逆)"
  read -erp "请选择 [y/n], 默认为 n:" uninstall_check
  [[ -z "${uninstall_check}" ]] && uninstall_check='n' &&  echo -e "${Info} 操作已取消..." && menu_SoraBot
  if [[ ${uninstall_check} == 'y' ]]; then
    cd ${WORK_DIR}
    check_pid_SoraBot
    [[ -z ${PID} ]] || kill -9 ${PID}
    echo -e "${Info} 开始卸载 SoraBot..."
    rm -rf SoraBot || echo -e "${Error} SoraBot 卸载失败！"

    echo -e "${Info} 开始卸载 ${python_v}..."
    [[ -d ${WORK_DIR}/${python_v} ]] && rm -rf ${python_v} || echo -e "${Error} ${python_v} 卸载失败！"
    
    echo -e "${Info} 开始卸载 openssl-1.1.1u..."
    [[ -d ${WORK_DIR}/openssl-1.1.1u ]] && rm -rf openssl-1.1.1u || echo -e "${Error} openssl-1.1.1u 卸载失败！"
    echo -e "${Info} 感谢使用林汐bot，期待于你的下次相会！"
  fi
  menu_SoraBot
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
    Set_config_env
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
    # echo -e "${Info} 开始运行 go-cqhttp..."
    # Start_cqhttp
    # View_cqhttp_log
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
  -- SoraBot | github.com/netsora --
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
 ${Green_font_prefix} 9.${Font_color_suffix} 切换为 SoraBot 菜单" && echo
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
  read -erp " 请输入数字 [0-9]:" num
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
  9)
    menu_SoraBot
    ;;
  *)
    echo "请输入正确数字 [0-9]"
    ;;
  esac
}

menu_SoraBot() {
  echo && echo -e "  SoraBot 一键安装管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  -- SoraBot | github.com/netsora --
 ${Green_font_prefix} 0.${Font_color_suffix} 升级脚本
 ————————————
 ${Green_font_prefix} 1.${Font_color_suffix} 安装 SoraBot 
————————————
 ${Green_font_prefix} 2.${Font_color_suffix} 启动 SoraBot
 ${Green_font_prefix} 3.${Font_color_suffix} 停止 SoraBot
 ${Green_font_prefix} 4.${Font_color_suffix} 重启 SoraBot
————————————
 ${Green_font_prefix} 5.${Font_color_suffix} 设置 频道机器人账号
 ${Green_font_prefix} 6.${Font_color_suffix} 修改 SoraBot 配置文件
————————————
 ${Green_font_prefix} 7.${Font_color_suffix} 查看 SoraBot 日志
 ${Green_font_prefix} 8.${Font_color_suffix} 卸载 SoraBot 以及组件 " && echo
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
  read -erp " 请输入数字 [0-9]:" num
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
    Set_config_env
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
    menu_cqhttp
    ;;
  *)
    echo "请输入正确数字 [0-9]"
    ;;
  esac
}

Set_work_dir
menu_SoraBot
