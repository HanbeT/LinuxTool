#!/bin/sh

# ログレベル(0：DEBUG/1：INFO/2：WARN/3：ERROR)
readonly LOG_LEVEL=0
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# ファイル区切り文字
readonly FILE_SPLIT_WORD="\\t"

# ヘッダー
readonly HEADER="ファイルパス・名${FILE_SPLIT_WORD}ファイル種別${FILE_SPLIT_WORD}パーミッション${FILE_SPLIT_WORD}パーミッション(8進数)${FILE_SPLIT_WORD}所有権(ユーザ)${FILE_SPLIT_WORD}所有権(グループ)${FILE_SPLIT_WORD}ファイルサイズ${FILE_SPLIT_WORD}ファイル更新日付${FILE_SPLIT_WORD}ファイル更新時刻${FILE_SPLIT_WORD}ファイル更新タイムゾーン"

function search() {
    # 処理対象ディレクトリ
    local now_dir=$1
    # カレントディレクトリと親ディレクトリを除外
    local target_list=`ls -a ${now_dir} | grep -v -E "\.$"`
    # ディレクトリフラグ(true：ディレクトリ/false：ファイル)
    local dir_flg=false
    # 対象処理ディレクトリから、基準となるディレクトリパスを除外
    local dir_prefix=${now_dir#${BASE_DIR}}

    for target in ${target_list};
    do
        # ディレクトリフラグを初期化
        dir_flg=false

        # ls情報を取得
        #   対象ファイルのみ取得
        #   シンボリックリンクを除外
        local ls_info=(`ls -la --full-time ${now_dir} | grep -E " ${target}$" | grep -v -E "\-> ${target}$"`)

        # パーミッション
        local permission=${ls_info[0]}
        # ユーザ
        local user=${ls_info[2]}
        # グループ
        local group=${ls_info[3]}
        # ファイルサイズ
        local f_size=${ls_info[4]}
        # ファイル更新日付
        local f_date=${ls_info[5]}
        # ファイル更新時刻
        local f_time=${ls_info[6]}
        # ファイル更新タイムゾーン
        local f_zone=${ls_info[7]}
        # ファイル種別
        local f_type=${permission:0:1}
        # ファイル名
        local filename=${ls_info[8]}

        case "${f_type}" in
            "d") # ディレクトリ
                dir_flg=true
                ;;

            "l") # シンボリックリンク
                # リンク先のファイル名を追加
                filename=${filename}${ls_info[9]}${ls_info[10]}
                ;;

            "-") # ファイル
                # ファイル種別を「f」に変更
                f_type="f"
                ;;

            *)   # 未対応のファイル種別の場合
                log ${LOG_LEVEL_WARN} "未対応のファイル種別が設定されています。：ファイル名=${now_dir}${filename}"
                EXIT_CODE=10
                ;;
        esac

        # TSVファイルに出力
        output "${dir_prefix}${filename}" "${f_type}" "${permission}" "`convert_rwx_to_hex ${permission} ${dir_prefix}${filename}`" "${user}" "${group}" "${f_size}" "${f_date}" "${f_time}" "${f_zone}"

        # ディレクトリの場合、サブディレクトリも探索
        if [ "${f_type}" == "d" ]; then
            search "${now_dir}${filename}/"
        fi
    done
    return 0
}

function convert_rwx_to_hex() {
    # rwx形式のパーミッション
    local rwx_permission=$1
    # 処理対象
    local target=$2
    # 8進数形式計算用パーミッション
    local tmp_hex_permission=0
    # 8進数形式のパーミッション
    local hex_permission=""

    local i=1
    while [ ${i} -lt 10 ];
    do
        # rwxを8進数に変換
        case "${rwx_permission:${i}:1}" in
            "r") # 読込権限あり
                tmp_hex_permission=$((tmp_hex_permission+4))
                ;;

            "w") # 書込権限あり
                tmp_hex_permission=$((tmp_hex_permission+2))
                ;;

            "x") # 実行権限あり
                tmp_hex_permission=$((tmp_hex_permission+1))
                ;;

            "-") # 権限なし
                tmp_hex_permission=$((tmp_hex_permission+0))
                ;;

            *)   # 未対応のファイル種別の場合
                log ${LOG_LEVEL_WARN} "未対応のパーミッションが設定されています。：ファイル名=${target}"
                EXIT_CODE=10
                echo "---"
                return 1
                ;;
        esac

        # パーミッションの対象が変更した場合(ループ変数が3の倍数の場合)、
        #  ・8進数用のパーミッションに計算後の結果を追加
        #  ・計算用パーミッションを初期化(0)
        if [ $((i%3)) -eq 0 ]; then
            hex_permission="${hex_permission}${tmp_hex_permission}"
            tmp_hex_permission=0
        fi
        i=$((i+1))
    done
    echo "${hex_permission}"
    return 0
}

function output() {
    echo -e "${1}${FILE_SPLIT_WORD}${2}${FILE_SPLIT_WORD}${3}${FILE_SPLIT_WORD}${4}${FILE_SPLIT_WORD}${5}${FILE_SPLIT_WORD}${6}${FILE_SPLIT_WORD}${7}${FILE_SPLIT_WORD}${8}${FILE_SPLIT_WORD}${9}${FILE_SPLIT_WORD}${10}" >> ${OUTPUT_DIR}${OUTPUT_FILE}
    return 0
}

function log() {
    # 出力時のログレベル
    local level=$1
    # 出力内容
    local message=$2
    # 出力用ログレベル
    local log_level_word=""

    if [ ${level} -ge ${LOG_LEVEL} ]; then
        case "${level}" in
            "${LOG_LEVEL_DEBUG}")
                log_level_word="[DEBUG]"
                ;;

            "${LOG_LEVEL_INFO}")
                log_level_word="[INFO ]"
                ;;

            "${LOG_LEVEL_WARN}")
                log_level_word="[WARN ]"
                ;;

            "${LOG_LEVEL_ERROR}")
                log_level_word="[ERROR]"
                ;;

            *)
                log_level_word="[-----]"
                ;;
        esac
        LOG_MESSAGE="${LOG_MESSAGE}\\n${log_level_word} ${message}"
    fi
    return 0
}

function output_log() {
    echo -e ${LOG_MESSAGE}
    echo
}

EXIT_CODE=0

LOG_MESSAGE=""

# 引数チェック
if [ $# -ne 1 ]; then
    log ${LOG_LEVEL_ERROR} "引数の数が間違っています。"
    log ${LOG_LEVEL_INFO} "  sh search_file_lsinfo.sh <target directory(absolute path)>"
    output_log
    exit 90
fi

# 基準ディレクトリ
BASE_DIR=$1

# ディレクトリ存在チェック
if [ ! -d "${BASE_DIR}" ]; then
    log ${LOG_LEVEL_ERROR} "指定されたディレクトリは存在しません。：${BASE_DIR}"
    output_log
    exit 91
fi

# 末尾が区切り文字かを判定
if [ "`echo ${BASE_DIR} | rev | cut -c 1-1`" != "/" ]; then
    BASE_DIR="${BASE_DIR}/"
fi

log ${LOG_LEVEL_INFO} "探索を開始します。"

# 出力ファイル作成
EXEC_DATE=`date +%Y%m%d%H%M%S`
OUTPUT_DIR="`pwd`/"
OUTPUT_FILE="_search_file_lsinfo_${EXEC_DATE}.tsv"

# 取得時刻を出力
echo -e "取得時刻：${FILE_SPLIT_WORD}${EXEC_DATE}" > ${OUTPUT_DIR}${OUTPUT_FILE}

# 基準ディレクトリを出力
echo -e "基準ディレクトリ：${FILE_SPLIT_WORD}${BASE_DIR}" >> ${OUTPUT_DIR}${OUTPUT_FILE}

# ヘッダーを出力
echo -e ${HEADER} >> ${OUTPUT_DIR}${OUTPUT_FILE}

# 探索処理呼び出し
search "${BASE_DIR}"

log ${LOG_LEVEL_INFO} "探索を終了しました。：${OUTPUT_DIR}${OUTPUT_FILE}"

output_log

exit "${EXIT_CODE}"
