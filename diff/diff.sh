#!/bin/sh

# ログレベル(0：DEBUG/1：INFO/2：WARN/3：ERROR)
readonly LOG_LEVEL=0
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

function before_diff() {
  local source=$1
  local destination=$2

  # ファイル
  for target in `find ${source} -type f`
  do
    get_diff "${source}" "${destination}" "f" "`str_replace ${target} ${source} ''`"
  done

  # ディレクトリ
  # find ${source} -type d > ${TMP_BEFORE}
  # sed -e "s|${source}||g" ${TMP_BEFORE} > ${TMP_AFTER}
  # diff "${source}" "${destination}" "d"

  # シンボリックリンク
  # find ${source} -type l > ${TMP_BEFORE}
  # sed -e "s|${source}||g" ${TMP_BEFORE} > ${TMP_AFTER}
  # diff "${source}" "${destination}" "l"
}

function get_diff() {
  local source=$1
  local destination=$2
  local f_type=$3
  local target=$4
  result=""

  ls -l ${destination}${target} &>/dev/null
  if [ $? -eq 0 ]; then
    case "${f_type}" in
      "d") # ディレクトリ
        ;;

      "l") # シンボリックリンク
        ;;

      "f") # ファイル
        result=`diff ${source}${target} ${destination}${target}`
        ;;

      *)   # 未対応のファイル種別の場合
        EXIT_CODE=10
        ;;
    esac

    if [ "${result}" == "" ]; then
      output_result "${OUTPUT_DIR_NODIFF}" "${source}" "${destination}" "${target}" ""
    else
      output_result "${OUTPUT_DIR_DIFF}" "${source}" "${destination}" "${target}" "${result}"
    fi
  else
    output_result "${OUTPUT_DIR_NONE}" "${source}" "${destination}" "${target}" ""
  fi

}

function str_replace() {
  local subject=$1
  local search=$2
  local replace=$3

  local tmp_before=${OUTPUT_DIR}/tmp_tmp_before.txt
  local tmp_after=${OUTPUT_DIR}/tmp_tmp_after.txt

  echo -n ${subject} > ${tmp_before}
  sed -e "s|${search}|${replace}|g" ${tmp_before} > ${tmp_after}

  echo `cat ${tmp_after}`
  rm -f ${tmp_before} ${tmp_after}
  return 0
}

function output_result() {
  local output_dir=$1
  local source=$2
  local destination=$3
  local target=$4
  local result=$5

  output_file=${output_dir}/`str_replace "${target}" "/" "_"`.txt

  echo "target: ${target}" > ${output_file}
  echo "source: ${source}${target}" >> ${output_file}
  echo "destination: ${destination}${target}" >> ${output_file}
  echo "" >> ${output_file}
  echo "${result}" >> ${output_file}
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

if [ $# -ne 2 ]; then
  log ${LOG_LEVEL_ERROR} "A mount of paramerter is wrong!"
  output_log
  exit 99
fi

source=$1
if [ ! -d ${source} ]; then
  log ${LOG_LEVEL_ERROR}  "Source directory is not exist!: ${source}"
  output_log
  exit 99
fi

destination=$2
if [ ! -d ${destination} ]; then
  log ${LOG_LEVEL_ERROR}  "Destination directory is not exist!: ${destination}"
  output_log
  exit 99
fi

log ${LOG_LEVEL_INFO} "比較を開始しました。"

EXEC_DATE=`date +%Y%m%d%H%M%S`
OUTPUT_DIR="`pwd`/_diff_${EXEC_DATE}"
OUTPUT_DIR_NONE="${OUTPUT_DIR}/none"
OUTPUT_DIR_NODIFF="${OUTPUT_DIR}/nodiff"
OUTPUT_DIR_DIFF="${OUTPUT_DIR}/diff"
mkdir ${OUTPUT_DIR} ${OUTPUT_DIR_NONE} ${OUTPUT_DIR_NODIFF} ${OUTPUT_DIR_DIFF}

before_diff "${source}" "${destination}"

log ${LOG_LEVEL_INFO} "比較を終了しました。：${OUTPUT_DIR}"

output_log
exit "${EXIT_CODE}"
