#!/bin/bash
set -o pipefail
set -o errtrace
set -o nounset
set -o errexit

function main {
    args=$(getopt -n "$(basename $0)" -o h --long help,debug,version -- "$@")
    eval set --"$args"
    while true; do
        case "$1" in
            -h | --help )
                print_usage
                shift
                ;;
            --debug )
                DEBUG=true
                shift
                ;;
            --version )
                print_version
                shift
                ;;
            --)
                shift
                break
                ;;
            * )
                break
                ;;
        esac
    done
    shift $((OPTIND-1))
    init
    for arg; do
        case "$arg" in
            import )
                if [ "$1" = "import" ]; then
                    import
                    exit
                fi
                ;;
            install )
                if [ "$1" = "install" ]; then
                    install
                    exit
                fi
                ;;
            magento )
                if [ "$1" = "magento" -a -f ${MAGE_ROOT}/bin/magento ]; then
                    su -l www-data -s /bin/bash -c "${MAGE_ROOT}/bin/magento ${*//magento/}"
                    exit
                fi
                ;;
            restart )
                if [ "$1" = "restart" -a -x $(which supervisorctl) ]; then
                    $(which supervisorctl) restart all
                    exit
                fi
                ;;
            start )
                if [ "$1" = "start" -a -x $(which supervisorctl) ]; then
                    $(which supervisorctl) start all
                    exit
                fi
                ;;
            status )
                if [ "$1" = "status" -a -x $(which supervisorctl) ]; then
                    $(which supervisorctl) status
                    exit
                fi
                ;;
            stop )
                if [ "$1" = "stop" -a -x $(which supervisorctl) ]; then
                    $(which supervisorctl) stop all
                    exit
                fi
                ;;
            supervisord )
                if [ "$1" = "supervisord" -a -x $(which supervisord) ]; then
                    config
                    install
                    supervisor ${*//supervisord/}
                    exit
                fi
                ;;
        esac
    done

    return
}

function init () {
    # Set Debug Mode
    : ${DEBUG:=false}

    [ "${DEBUG}" = "true" ] && set -x

    # Set Supervisor Defaults
    : ${SUPERVISOR_USERNAME:=admin}
    : ${SUPERVISOR_PASSWORD:=$(cat /dev/urandom | tr -d -c a-z0-9- | dd bs=1 count=$((RANDOM%(24-16+1)+16)) 2> /dev/null)}

    # Set Magento2 Defaults
    : ${MAGENTO_PUBLIC_KEY:=}
    : ${MAGENTO_PRIVATE_KEY:=}
    : ${MAGENTO_ROOT:=/var/www}
    : ${MAGENTO_SRC:=/usr/src/magento2}
    : ${MAGENTO_INSTALLER:=default}
    : ${MAGENTO_ADMIN_FIRSTNAME:=Magento}
    : ${MAGENTO_ADMIN_LASTNAME:=Administrator}
    : ${MAGENTO_ADMIN_EMAIL:=}
    : ${MAGENTO_ADMIN_USER:=admin}
    : ${MAGENTO_ADMIN_PASSWORD:=$(cat /dev/urandom | tr -d -c a-z0-9- | dd bs=1 count=$((RANDOM%(24-16+1)+16)) 2> /dev/null)}
    : ${MAGENTO_BACKEND_FRONTNAME:=}
    : ${MAGENTO_BASE_URL:=}
    : ${MAGENTO_BASE_URL_SECURE:=}
    : ${MAGENTO_CACHE_BACKEND:=}
    : ${MAGENTO_CACHE_BACKEND_REDIS_DB:=}
    : ${MAGENTO_CACHE_BACKEND_REDIS_PORT:=}
    : ${MAGENTO_CACHE_BACKEND_REDIS_SERVER:=}
    : ${MAGENTO_CATALOG_IMPORT:=false}
    : ${MAGENTO_CONFIG_DATA:=true}
    : ${MAGENTO_CURRENCY:=}
    : ${MAGENTO_DB_HOST:=localhost}
    : ${MAGENTO_DB_NAME:=magento}
    : ${MAGENTO_DB_USER:=root}
    : ${MAGENTO_DB_PASSWORD:=}
    : ${MAGENTO_DEPLOY_MODE:=}
    : ${MAGENTO_GERMAN_LANGUAGE:=false}
    : ${MAGENTO_GERMAN_SETUP:=false}
    : ${MAGENTO_LANGUAGE:=}
    : ${MAGENTO_PAGE_CACHE:=}
    : ${MAGENTO_PAGE_CACHE_REDIS_COMPRESS_DATA:=}
    : ${MAGENTO_PAGE_CACHE_REDIS_DB:=}
    : ${MAGENTO_PAGE_CACHE_REDIS_PORT:=}
    : ${MAGENTO_PAGE_CACHE_REDIS_SERVER:=}
    : ${MAGENTO_SESSION_SAVE:=}
    : ${MAGENTO_SESSION_SAVE_REDIS_DB:=}
    : ${MAGENTO_SESSION_SAVE_REDIS_HOST:=}
    : ${MAGENTO_SESSION_SAVE_REDIS_LOG_LEVEL:=}
    : ${MAGENTO_SESSION_SAVE_REDIS_PORT:=}
    : ${MAGENTO_SHIPPING_CITY:=}
    : ${MAGENTO_SHIPPING_POSTCODE:=}
    : ${MAGENTO_TAX_POSTCODE:=}
    : ${MAGENTO_TIMEZONE:=}
    : ${MAGENTO_USE_REWRITES:=}
    : ${MAGENTO_USE_SECURE:=}
    : ${MAGENTO_USE_SECURE_ADMIN:=}

    # Set Magento2 Modules
    : ${BS_PAYONE:=false}

    # Magento Config Data
    if [ "${MAGENTO_CONFIG_DATA}" != "false" ]; then
        CORE_CONFIG_DATA=(
            "default" "0" "admin/dashboard/enable_charts" "${MAGENTO_ADMIN_DASHBOARD_ENABLE_CHARTS:=0}"
            "default" "0" "design/theme/theme_id" "${MAGENTO_DESIGN_THEME_THEME_ID:=2}"
            "default" "0" "design/pagination/pagination_frame" "${MAGENTO_DESIGN_PAGINATION_PAGINATION_FRAME:=5}"
            "default" "0" "design/pagination/pagination_frame_skip" "${MAGENTO_DESIGN_PAGINATION_PAGINATION_FRAME_SKIP:=NULL}"
            "default" "0" "design/pagination/anchor_text_for_previous" "${MAGENTO_DESIGN_PAGINATION_ANCHOR_TEXT_FOR_PREVIOUS:=NULL}"
            "default" "0" "design/pagination/anchor_text_for_next" "${MAGENTO_DESIGN_PAGINATION_ANCHOR_TEXT_FOR_NEXT:=NULL}"
            "default" "0" "design/head/default_title" "${MAGENTO_DESIGN_HEAD_DEFAULT_TITLE:=Magento Commerce}"
            "default" "0" "design/head/title_prefix" "${MAGENTO_DESIGN_HEAD_TITLE_PREFIX:=NULL}"
            "default" "0" "design/head/title_suffix" "${MAGENTO_DESIGN_HEAD_TITLE_SUFFIX:=NULL}"
            "default" "0" "design/head/default_description" "${MAGENTO_DESIGN_HEAD_DEFAULT_DESCRIPTION:=NULL}"
            "default" "0" "design/head/default_keywords" "${MAGENTO_DESIGN_HEAD_DEFAULT_KEYWORDS:=NULL}"
            "default" "0" "design/head/includes" "${MAGENTO_DESIGN_HEAD_INCLUDES:=NULL}"
            "default" "0" "design/head/demonotice" "${MAGENTO_DESIGN_HEAD_DEMONOTICE:=0}"
            "default" "0" "design/header/logo_width" "${MAGENTO_DESIGN_HEADER_LOGO_WIDTH:=NULL}"
            "default" "0" "design/header/logo_height" "${MAGENTO_DESIGN_HEADER_LOGO_HEIGHT:=NULL}"
            "default" "0" "design/header/logo_alt" "${MAGENTO_DESIGN_HEADER_LOGO_ALT:=NULL}"
            "default" "0" "design/header/welcome" "${MAGENTO_DESIGN_HEADER_WELCOME:=Default welcome msg!}"
            "default" "0" "design/footer/copyright" "${MAGENTO_DESIGN_FOOTER_COPYRIGHT:=Copyright © 2013-2017 Magento, Inc. All rights reserved.}"
            "default" "0" "design/footer/absolute_footer" "${MAGENTO_DESIGN_FOOTER_ABSOLUTE_FOOTER:=NULL}"
            "default" "0" "design/search_engine_robots/default_robots" "${MAGENTO_DESIGN_SEARCH_ENGINE_ROBOTS_DEFAULT_ROBOTS:=INDEX,FOLLOW}"
            "default" "0" "design/search_engine_robots/custom_instructions" "${MAGENTO_DESIGN_SEARCH_ENGINE_ROBOTS_CUSTOM_INSTRUCTIONS:=NULL}"
            "default" "0" "design/watermark/image_size" "${MAGENTO_DESIGN_WATERMARK_IMAGE_SIZE:=NULL}"
            "default" "0" "design/watermark/image_imageOpacity" "${MAGENTO_DESIGN_WATERMARK_IMAGE_IMAGEOPACITY:=NULL}"
            "default" "0" "design/watermark/image_position" "${MAGENTO_DESIGN_WATERMARK_IMAGE_POSITION:=stretch}"
            "default" "0" "design/watermark/small_image_size" "${MAGENTO_DESIGN_WATERMARK_SMALL_IMAGE_SIZE:=NULL}"
            "default" "0" "design/watermark/small_image_imageOpacity" "${MAGENTO_DESIGN_WATERMARK_SMALL_IMAGE_IMAGEOPACITY:=NULL}"
            "default" "0" "design/watermark/small_image_position" "${MAGENTO_DESIGN_WATERMARK_SMALL_IMAGE_POSITION:=stretch}"
            "default" "0" "design/watermark/thumbnail_size" "${MAGENTO_DESIGN_WATERMARK_THUMBNAIL_SIZE:=NULL}"
            "default" "0" "design/watermark/thumbnail_imageOpacity" "${MAGENTO_DESIGN_WATERMARK_THUMBNAIL_IMAGEOPACITY:=NULL}"
            "default" "0" "design/watermark/thumbnail_position" "${MAGENTO_DESIGN_WATERMARK_THUMBNAIL_POSITION:=stretch}"
            "default" "0" "design/email/logo_alt" "${MAGENTO_DESIGN_EMAIL_LOGO_ALT:=NULL}"
            "default" "0" "design/email/logo_width" "${MAGENTO_DESIGN_EMAIL_LOGO_WIDTH:=NULL}"
            "default" "0" "design/email/logo_height" "${MAGENTO_DESIGN_EMAIL_LOGO_HEIGHT:=NULL}"
            "default" "0" "design/email/header_template" "${MAGENTO_DESIGN_EMAIL_HEADER_TEMPLATE:=design_email_header_template}"
            "default" "0" "design/email/footer_template" "${MAGENTO_DESIGN_EMAIL_FOOTER_TEMPLATE:=design_email_footer_template}"
            "default" "0" "design/watermark/swatch_image_size" "${MAGENTO_DESIGN_WATERMARK_SWATCH_IMAGE_SIZE:=NULL}"
            "default" "0" "design/watermark/swatch_image_imageOpacity" "${MAGENTO_DESIGN_WATERMARK_SWATCH_IMAGE_IMAGEOPACITY:=NULL}"
            "default" "0" "design/watermark/swatch_image_position" "${MAGENTO_DESIGN_WATERMARK_SWATCH_IMAGE_POSITION:=stretch}"
            "default" "0" "general/country/allow" "${MAGENTO_GENERAL_COUNTRY_ALLOW:=AF,EG,AX,AL,DZ,VI,UM,AS,AD,AO,AI,AQ,AG,GQ,AR,AM,AW,AZ,ET,AU,BS,BH,BD,BB,BY,BE,BZ,BJ,BM,BT,BO,BA,BW,BV,BR,VG,IO,BN,BG,BF,BI,CL,CN,CK,CR,CI,DK,DE,DM,DO,DJ,EC,SV,ER,EE,FK,FO,FJ,FI,FR,TF,GF,PF,GA,GM,GE,GH,GI,GD,GR,GL,GP,GU,GT,GG,GN,GW,GY,HT,HM,HN,IN,ID,IQ,IR,IE,IS,IM,IL,IT,JM,JP,YE,JE,JO,KY,KH,CM,CA,CV,KZ,QA,KE,KG,KI,CC,CO,KM,CG,CD,HR,CU,KW,LA,LS,LV,LB,LR,LY,LI,LT,LU,MG,MW,MY,MV,ML,MT,MA,MH,MQ,MR,MU,YT,MK,MX,FM,MC,MN,ME,MS,MZ,MM,NA,NR,NP,NC,NZ,NI,NL,NE,NG,NU,KP,MP,NF,NO,OM,AT,PK,PS,PW,PA,PG,PY,PE,PH,PN,PL,PT,MD,RE,RW,RO,RU,SB,ZM,WS,SM,ST,SA,SE,CH,SN,RS,SC,SL,ZW,SG,SK,SI,SO,MO,HK,ES,LK,BL,SH,KN,LC,MF,PM,VC,ZA,SD,GS,KR,SR,SJ,SZ,SY,TJ,TW,TZ,TH,TL,TG,TK,TO,TT,TD,CZ,TN,TR,TM,TC,TV,UG,UA,HU,UY,UZ,VU,VA,VE,AE,GB,US,VN,WF,CX,EH,CF,CY}"
            "default" "0" "general/country/optional_zip_countries" "${MAGENTO_GENERAL_COUNTRY_OPTIONAL_ZIP_COUNTRIES:=IE,PA,MO,HK,GB}"
            "default" "0" "general/country/eu_countries" "${MAGENTO_GENERAL_COUNTRY_EU_COUNTRIES:=BE,BG,DK,DE,EE,FI,FR,GR,IE,IT,HR,LV,LT,LU,MT,NL,AT,PL,PT,RO,SE,SK,SI,ES,CZ,HU,GB,CY}"
            "default" "0" "general/locale/weekend" "${MAGENTO_GENERAL_LOCALE_WEEKEND:=0,6}"
            "default" "0" "general/locale/weight_unit" "${MAGENTO_GENERAL_LOCALE_WEIGHT_UNIT:=lbs}"
            "default" "0" "general/store_information/name" "${MAGENTO_GENERAL_STORE_INFORMATION_NAME:=NULL}"
            "default" "0" "general/store_information/phone" "${MAGENTO_GENERAL_STORE_INFORMATION_PHONE:=NULL}"
            "default" "0" "general/store_information/hours" "${MAGENTO_GENERAL_STORE_INFORMATION_HOURS:=NULL}"
            "default" "0" "general/store_information/country_id" "${MAGENTO_GENERAL_STORE_INFORMATION_COUNTRY_ID:=NULL}"
            "default" "0" "general/store_information/region_id" "${MAGENTO_GENERAL_STORE_INFORMATION_REGION_ID:=NULL}"
            "default" "0" "general/store_information/postcode" "${MAGENTO_GENERAL_STORE_INFORMATION_POSTCODE:=NULL}"
            "default" "0" "general/store_information/city" "${MAGENTO_GENERAL_STORE_INFORMATION_CITY:=NULL}"
            "default" "0" "general/store_information/street_line1" "${MAGENTO_GENERAL_STORE_INFORMATION_STREET_LINE1:=NULL}"
            "default" "0" "general/store_information/street_line2" "${MAGENTO_GENERAL_STORE_INFORMATION_STREET_LINE2:=NULL}"
            "default" "0" "general/store_information/merchant_vat_number" "${MAGENTO_GENERAL_STORE_INFORMATION_VAT_NUMBER:=NULL}"
            "default" "0" "general/single_store_mode/enabled" "${MAGENTO_GENERAL_SINGLE_STORE_MODE_ENABLED:=NULL}"
            "default" "0" "general/imprint/shop_name" "${MAGENTO_GENERAL_IMPRINT_SHOP_NAME:=NULL}"
            "default" "0" "general/imprint/company_first" "${MAGENTO_GENERAL_IMPRINT_COMPANY_FIRST:=NULL}"
            "default" "0" "general/imprint/company_second" "${MAGENTO_GENERAL_IMPRINT_COMPANY_SECOND:=NULL}"
            "default" "0" "general/imprint/street" "${MAGENTO_GENERAL_IMPRINT_STREET:=NULL}"
            "default" "0" "general/imprint/zip" "${MAGENTO_GENERAL_IMPRINT_ZIP:=NULL}"
            "default" "0" "general/imprint/city" "${MAGENTO_GENERAL_IMPRINT_CITY:=NULL}"
            "default" "0" "general/imprint/country" "${MAGENTO_GENERAL_IMPRINT_COUNTRY:=NULL}"
            "default" "0" "general/imprint/telephone" "${MAGENTO_GENERAL_IMPRINT_TELEPHONE:=NULL}"
            "default" "0" "general/imprint/telephone_additional" "${MAGENTO_GENERAL_IMPRINT_TELEPHONE_ADDITIONAL:=NULL}"
            "default" "0" "general/imprint/fax" "${MAGENTO_GENERAL_IMPRINT_FAX:=NULL}"
            "default" "0" "general/imprint/email" "${MAGENTO_GENERAL_IMPRINT_EMAIL:=NULL}"
            "default" "0" "general/imprint/web" "${MAGENTO_GENERAL_IMPRINT_WEB:=NULL}"
            "default" "0" "general/imprint/tax_number" "${MAGENTO_GENERAL_IMPRINT_TAX_NUMBER:=NULL}"
            "default" "0" "general/imprint/vat_id" "${MAGENTO_GENERAL_IMPRINT_VAT_ID:=NULL}"
            "default" "0" "general/imprint/court" "${MAGENTO_GENERAL_IMPRINT_COURT:=NULL}"
            "default" "0" "general/imprint/financial_office" "${MAGENTO_GENERAL_IMPRINT_FINANCIAL_OFFICE:=NULL}"
            "default" "0" "general/imprint/ceo" "${MAGENTO_GENERAL_IMPRINT_CEO:=NULL}"
            "default" "0" "general/imprint/owner" "${MAGENTO_GENERAL_IMPRINT_OWNER:=NULL}"
            "default" "0" "general/imprint/content_responsable_name" "${MAGENTO_GENERAL_IMPRINT_CONTENT_RESPONSABLE_NAME:=NULL}"
            "default" "0" "general/imprint/content_responsable_address" "${MAGENTO_GENERAL_IMPRINT_CONTENT_RESPONSABLE_ADDRESS:=NULL}"
            "default" "0" "general/imprint/content_responsable_press_law" "${MAGENTO_GENERAL_IMPRINT_CONTENT_RESPONSABLE_PRESS_LAW:=NULL}"
            "default" "0" "general/imprint/register_number" "${MAGENTO_GENERAL_IMPRINT_REGISTER_NUMBER:=NULL}"
            "default" "0" "general/imprint/business_rules" "${MAGENTO_GENERAL_IMPRINT_BUSINESS_RULE:=NULL}"
            "default" "0" "general/imprint/authority" "${MAGENTO_GENERAL_IMPRINT_AUTHORITY:=NULL}"
            "default" "0" "general/imprint/shareholdings" "${MAGENTO_GENERAL_IMPRINT_SHAREHOLDINGS:=NULL}"
            "default" "0" "general/imprint/editorial_concept" "${MAGENTO_GENERAL_IMPRINT_EDITORIAL_CONCEPT:=NULL}"
            "default" "0" "general/imprint/bank_account_owner" "${MAGENTO_GENERAL_IMPRINT_BANK_ACCOUNT_OWNER:=NULL}"
            "default" "0" "general/imprint/bank_account" "${MAGENTO_GENERAL_IMPRINT_BANK_ACCOUNT:=NULL}"
            "default" "0" "general/imprint/bank_code_number" "${MAGENTO_GENERAL_IMPRINT_BANK_CODE_NUMBER:=NULL}"
            "default" "0" "general/imprint/bank_name" "${MAGENTO_GENERAL_IMPRINT_BANK_NAME:=NULL}"
            "default" "0" "general/imprint/swift" "${MAGENTO_GENERAL_IMPRINT_SWIFT:=NULL}"
            "default" "0" "general/imprint/iban" "${MAGENTO_GENERAL_IMPRINT_IBAN:=NULL}"
            "default" "0" "general/imprint/clearing" "${MAGENTO_GENERAL_IMPRINT_CLEARING:=NULL}"
        )
    fi

    return
}

function config () {
    if [ -z "${MAGENTO_PUBLIC_KEY}" -o -z "${MAGENTO_PRIVATE_KEY}" ]; then
        print_auth
    fi

    if [ "$MAGENTO_ROOT" != "/var/www" ]; then
        usermod -d ${MAGENTO_ROOT} www-data
    fi

    if [ -x /usr/sbin/cron ]; then
        echo '* * * * *     www-data   /usr/bin/php /var/www/bin/magento cron:run | grep -v "Ran jobs by schedule" >> /var/www/var/log/cron.log' > /etc/cron.d/magento2
    fi

    if [ "$(id -u www-data)" != "999" ]; then
        groupmod -g 999 www-data
        usermod -u 999 www-data
    fi

    sed -i -e "s/dc_eximconfig_configtype=.*/dc_eximconfig_configtype='internet'/" /etc/exim4/update-exim4.conf.conf
    sed -i -e "s/dc_other_hostnames=.*/dc_other_hostnames='$(hostname --fqdn)'/" /etc/exim4/update-exim4.conf.conf
    sed -i -e "s/dc_local_interfaces=.*/dc_local_interfaces='127.0.0.1'/" /etc/exim4/update-exim4.conf.conf

    echo $(hostname) > /etc/mailname

    update-exim4.conf

    if [ -d /etc/nginx/conf.d ]; then
        echo "upstream fastcgi_backend {" > /etc/nginx/conf.d/upstream.conf
        echo "    server unix:/run/php/php7.0-fpm.sock;" >> /etc/nginx/conf.d/upstream.conf
        echo "}" >> /etc/nginx/conf.d/upstream.conf
    fi

    if [ -f /etc/nginx/nginx.conf ]; then
        sed -i -e "s/# server_tokens \(.*\);/server_tokens \1;/" -e "s/server_tokens \(.*\);/server_tokens off;/" /etc/nginx/nginx.conf
    fi

    if [ -f /etc/nginx/sites-available/default ]; then
        sed -i -e "s/root \(.*\);/root \/var\/www\/magento2;/" /etc/nginx/sites-available/default
        sed -i -e "s/# listen 443 ssl default_server;/listen 443 ssl default_server http2;/" /etc/nginx/sites-available/default;
        sed -i -e "s/# listen \[::\]:443 ssl default_server;/listen [::]:443 ssl default_server http2;/" /etc/nginx/sites-available/default
        sed -i -e "s/# include snippets\/snakeoil.conf;/include snippets\/snakeoil.conf;/" /etc/nginx/sites-available/default
        echo -e "server {" > /etc/nginx/sites-available/default
        echo -e "\tlisten 80 default_server;" >> /etc/nginx/sites-available/default
        echo -e "\tlisten [::]:80 default_server;\n" >> /etc/nginx/sites-available/default
        echo -e "\tlisten 443 ssl default_server http2;" >> /etc/nginx/sites-available/default
        echo -e "\tlisten [::]:443 ssl default_server http2;\n" >> /etc/nginx/sites-available/default
        echo -e "\tserver_name _;\n" >> /etc/nginx/sites-available/default
        echo -e "\tset \$MAGE_ROOT ${MAGENTO_ROOT};\n" >> /etc/nginx/sites-available/default
        echo -e "\tinclude snippets/magento2.conf;" >> /etc/nginx/sites-available/default
        echo -e "\tinclude snippets/snakeoil.conf;" >> /etc/nginx/sites-available/default
        echo -e "}" >> /etc/nginx/sites-available/default
    fi

    if [ ! -d /run/php ]; then
        mkdir -p /run/php
    fi

    if [ -f /etc/php/7.0/fpm/php.ini ]; then
        sed -i -e "s/expose_php = On/expose_php = Off/" /etc/php/7.0/fpm/php.ini
    fi

    if [ -f /etc/php/7.0/fpm/pool.d/www.conf ]; then
        sed -i -e "s/listen = \/run\/php\/php7.0-fpm.sock/listen = \/run\/php\/php7.0-fpm.sock/" /etc/php/7.0/fpm/pool.d/www.conf
        sed -i -e "s/;security.limit_extensions = .php .php3 .php4 .php5 .php7/security.limit_extensions = .php/" /etc/php/7.0/fpm/pool.d/www.conf
    fi

    return
}

function import ()
{
    if [ -d /etc/docker-entrypoint.d ]; then
        for PACKAGE in /etc/docker-entrypoint.d/*; do
            case "$PACKAGE" in
                *.7z)
                    if [ -e "$(which 7zr)" ]; then
                        if [ "${UID}" -eq 0 ]; then
                            su -s /bin/bash www-data -c "7zr x -y $PACKAGE > /dev/null"
                        else
                            7zr x -y $PACKAGE > /dev/null
                        fi
                    fi
                    ;;
                *.tar.bz2)
                    if [ -e "$(which tar)" ]; then
                        if [ "${UID}" -eq 0 ]; then
                            su -s /bin/bash www-data -c "tar xfj $PACKAGE"
                        else
                            tar xfj $PACKAGE
                        fi
                    fi
                    ;;
                *.tar.gz)
                    if [ -e "$(which tar)" ]; then
                        if [ "${UID}" -eq 0 ]; then
                            su -s /bin/bash www-data -c "tar xfz $PACKAGE"
                        else
                            tar xfz $PACKAGE
                        fi
                    fi
                    ;;
                *.tar.xz)
                    if [ -e "$(which tar)" ]; then
                        if [ "${UID}" -eq 0 ]; then
                            su -s /bin/bash www-data -c "tar xfJ $PACKAGE"
                        else
                            tar xfJ $PACKAGE
                        fi
                    fi
                    ;;
                *.zip)
                    if [ -e "$(which unzip)" ]; then
                        if [ "${UID}" -eq 0 ]; then
                            su -s /bin/bash www-data -c "unzip -o -q $PACKAGE"
                        else
                            unzip -o -q $PACKAGE
                        fi
                    fi
                    ;;
                *) ;;
            esac
        done
    fi

    return
}

function install () {
    if [ -d ${MAGENTO_ROOT} ]; then
        rm -rf ${MAGENTO_ROOT}/*
        chmod 770 ${MAGENTO_ROOT}
    else
        mkdir -m 770 -p ${MAGENTO_ROOT}
    fi

    chown www-data: ${MAGENTO_ROOT}

    case "${MAGENTO_INSTALLER}" in
        composer )
            git init > /dev/null
            cp -pr ${MAGENTO_SRC}/auth.json.sample ${MAGENTO_ROOT}/auth.json
            cp -pr ${MAGENTO_SRC}/composer.json ${MAGENTO_ROOT}
            sed -i "s/\"username\": \"\(.*\)\"/\"username\": \"${MAGENTO_PUBLIC_KEY}\"/" ${MAGENTO_ROOT}/auth.json
            sed -i "s/\"password\": \"\(.*\)\"/\"password\": \"${MAGENTO_PRIVATE_KEY}\"/" ${MAGENTO_ROOT}/auth.json
            magento-composer config repositories.magento composer https://repo.magento.com/
            magento-composer install
            chown -R www-data:www-data ${MAGENTO_ROOT}
            git add --all > /dev/null
            git commit -m "Initial commit" > /dev/null
            ;;
        * )
            git init > /dev/null
            rsync -a ${MAGENTO_SRC}/ ${MAGENTO_ROOT}/
            cp -pr ${MAGENTO_ROOT}/auth.json.sample ${MAGENTO_ROOT}/auth.json
            sed -i "s/\"username\": \"\(.*\)\"/\"username\": \"${MAGENTO_PUBLIC_KEY}\"/" ${MAGENTO_ROOT}/auth.json
            sed -i "s/\"password\": \"\(.*\)\"/\"password\": \"${MAGENTO_PRIVATE_KEY}\"/" ${MAGENTO_ROOT}/auth.json
            chown -R www-data:www-data ${MAGENTO_ROOT}
            git add --all > /dev/null
            git commit -m "Initial commit" > /dev/null
            ;;
    esac

    import

    if [ -n "${MAGENTO_BASE_URL}" -a -n "${MAGENTO_DB_PASSWORD}" ]; then
        mysql -u ${MAGENTO_DB_USER} -p${MAGENTO_DB_PASSWORD} -e "DROP DATABASE IF EXISTS ${MAGENTO_DB_NAME}; CREATE DATABASE ${MAGENTO_DB_NAME}"

        OPTS="setup:install"

        OPTS=" ${OPTS} --base-url=${MAGENTO_BASE_URL}"

        if [ -n "${MAGENTO_BASE_URL_SECURE}" ]; then
            OPTS=" ${OPTS} --base-url-secure=${MAGENTO_BASE_URL_SECURE}"
        fi

        OPTS=" ${OPTS} --admin-firstname=${MAGENTO_ADMIN_FIRSTNAME}"
        OPTS=" ${OPTS} --admin-lastname=${MAGENTO_ADMIN_LASTNAME}"
        OPTS=" ${OPTS} --admin-email=${MAGENTO_ADMIN_EMAIL}"
        OPTS=" ${OPTS} --admin-user=${MAGENTO_ADMIN_USER}"
        OPTS=" ${OPTS} --admin-password=${MAGENTO_ADMIN_PASSWORD}"

        if [ -n "${MAGENTO_BACKEND_FRONTNAME}" ]; then
            OPTS=" ${OPTS} --backend-frontname=${MAGENTO_BACKEND_FRONTNAME}"
        fi

        if [ -n "${MAGENTO_CACHE_BACKEND}" ]; then
            OPTS=" ${OPTS} --cache-backend=${MAGENTO_CACHE_BACKEND}"
        fi

        if [ -n "${MAGENTO_CURRENCY}" ]; then
            OPTS=" ${OPTS} --currency=${MAGENTO_CURRENCY}"
        fi

        if [ -n "${MAGENTO_CACHE_BACKEND}" ]; then
            OPTS=" ${OPTS} --cache-backend=${MAGENTO_CACHE_BACKEND}"
        fi

        if [ -n "${MAGENTO_CACHE_BACKEND_REDIS_DB}" ]; then
            OPTS=" ${OPTS} --cache-backend-redis-db=${MAGENTO_CACHE_BACKEND_REDIS_DB}"
        fi

        if [ -n "${MAGENTO_CACHE_BACKEND_REDIS_PORT}" ]; then
            OPTS=" ${OPTS} --cache-backend-redis-port=${MAGENTO_CACHE_BACKEND_REDIS_PORT}"
        fi

        if [ -n "${MAGENTO_CACHE_BACKEND_REDIS_SERVER}" ]; then
            OPTS=" ${OPTS} --cache-backend-redis-server=${MAGENTO_CACHE_BACKEND_REDIS_SERVER}"
        fi

        OPTS=" ${OPTS} --db-host=${MAGENTO_DB_HOST}"
        OPTS=" ${OPTS} --db-name=${MAGENTO_DB_NAME}"
        OPTS=" ${OPTS} --db-user=${MAGENTO_DB_USER}"
        OPTS=" ${OPTS} --db-password=${MAGENTO_DB_PASSWORD}"

        if [ -n "${MAGENTO_LANGUAGE}" ]; then
            OPTS=" ${OPTS} --language=${MAGENTO_LANGUAGE}"
        fi

        if [ -n "${MAGENTO_PAGE_CACHE}" ]; then
            OPTS=" ${OPTS} --page-cache=${MAGENTO_PAGE_CACHE}"
        fi

        if [ -n "${MAGENTO_PAGE_CACHE_REDIS_COMPRESS_DATA}" ]; then
            OPTS=" ${OPTS} --page-cache-redis-compress-data=${MAGENTO_PAGE_CACHE_REDIS_COMPRESS_DATA}"
        fi

        if [ -n "${MAGENTO_PAGE_CACHE_REDIS_DB}" ]; then
            OPTS=" ${OPTS} --page-cache-redis-db=${MAGENTO_PAGE_CACHE_REDIS_DB}"
        fi

        if [ -n "${MAGENTO_PAGE_CACHE_REDIS_PORT}" ]; then
            OPTS=" ${OPTS} --page-cache-redis-port=${MAGENTO_PAGE_CACHE_REDIS_PORT}"
        fi

        if [ -n "${MAGENTO_PAGE_CACHE_REDIS_SERVER}" ]; then
            OPTS=" ${OPTS} --page-cache-redis-server=${MAGENTO_PAGE_CACHE_REDIS_SERVER}"
        fi

        if [ -n "${MAGENTO_SESSION_SAVE}" ]; then
            OPTS=" ${OPTS} --session-save=${MAGENTO_SESSION_SAVE}"
        fi

        if [ -n "${MAGENTO_SESSION_SAVE_REDIS_DB}" ]; then
            OPTS=" ${OPTS} --session-save-redis-db=${MAGENTO_SESSION_SAVE_REDIS_DB}"
        fi

        if [ -n "${MAGENTO_SESSION_SAVE_REDIS_HOST}" ]; then
            OPTS=" ${OPTS} --session-save-redis-host=${MAGENTO_SESSION_SAVE_REDIS_HOST}"
        fi

        if [ -n "${MAGENTO_SESSION_SAVE_REDIS_LOG_LEVEL}" ]; then
            OPTS=" ${OPTS} --session-save-redis-log-level=${MAGENTO_SESSION_SAVE_REDIS_LOG_LEVEL}"
        fi

        if [ -n "${MAGENTO_SESSION_SAVE_REDIS_PORT}" ]; then
            OPTS=" ${OPTS} --session-save-redis-port=${MAGENTO_SESSION_SAVE_REDIS_PORT}"
        fi

        if [ -n "${MAGENTO_TIMEZONE}" ]; then
            OPTS=" ${OPTS} --timezone=${MAGENTO_TIMEZONE}"
        fi

        if [ -n "${MAGENTO_USE_REWRITES}" ]; then
            OPTS=" ${OPTS} --use-rewrites=${MAGENTO_USE_REWRITES}"
        fi

        if [ -n "${MAGENTO_USE_SECURE}" ]; then
            OPTS=" ${OPTS} --use-secure=${MAGENTO_USE_SECURE}"
        fi

        magento ${OPTS}

        if [ "${MAGENTO_CONFIG_DATA}" != "false" ]; then
            mysql -u ${MAGENTO_DB_USER} -p${MAGENTO_DB_PASSWORD} -e "UPDATE design_config_grid_flat SET theme_theme_id = '${MAGENTO_DESIGN_THEME_THEME_ID:=2}'" ${MAGENTO_DB_NAME}
        
            for I in $(seq 0 4 $((${#CORE_CONFIG_DATA[@]}-1))); do
                core_config_data "${CORE_CONFIG_DATA[$I]}" "${CORE_CONFIG_DATA[$I+1]}" "${CORE_CONFIG_DATA[$I+2]}" "${CORE_CONFIG_DATA[$I+3]}"
            done

            if [ -n "${MAGENTO_SHIPPING_CITY}" ]; then
                magento config:set "shipping/origin/city" "${MAGENTO_SHIPPING_CITY}"
            fi

            if [ -n "${MAGENTO_SHIPPING_POSTCODE}" ]; then
                magento config:set "shipping/origin/postcode" "${MAGENTO_SHIPPING_POSTCODE}"
            fi

            if [ -n "${MAGENTO_TAX_POSTCODE}" ]; then
                magento config:set "tax/defaults/postcode" "${MAGENTO_TAX_POSTCODE}"
            fi
        fi

        if [ -n "${MAGENTO_DEPLOY_MODE}" ]; then
            magento deploy:mode:set "${MAGENTO_DEPLOY_MODE}"
        fi

        if [ -n "${MAGENTO_LANGUAGE}" ]; then
            mysql -u ${MAGENTO_DB_USER} -p${MAGENTO_DB_PASSWORD} -e "UPDATE admin_user SET interface_locale = '${MAGENTO_LANGUAGE}'" ${MAGENTO_DB_NAME}
        fi

        magento_modules

        mysql -u ${MAGENTO_DB_USER} -p${MAGENTO_DB_PASSWORD} -e "DELETE FROM integration WHERE name = 'Magento Social'" ${MAGENTO_DB_NAME}
    fi

    git add --all > /dev/null
    git commit -m "Magento2 Version 2.2.2" > /dev/null

    return
}

function core_config_data () {
    if [ "$4" != "NULL" ]; then
        mysql -u ${MAGENTO_DB_USER} -p${MAGENTO_DB_PASSWORD} -e "INSERT INTO core_config_data (scope, scope_id, path, value) VALUES ('$1', '$2', '$3', '$4')" ${MAGENTO_DB_NAME}
    else
        mysql -u ${MAGENTO_DB_USER} -p${MAGENTO_DB_PASSWORD} -e "INSERT INTO core_config_data (scope, scope_id, path, value) VALUES ('$1', '$2', '$3', NULL)" ${MAGENTO_DB_NAME}
    fi

    return
}

function magento_modules () {
    if [ "${BS_PAYONE}" != "false" ]; then
        magento-composer require payone-gmbh/magento-2
        magento setup:upgrade
        magento setup:di:compile
        magento cache:clean
    fi

    if [ "${MAGENTO_GERMAN_LANGUAGE}" != "false" ]; then
        magento-composer require wilkesystems/magento2-german-language:dev-master
    fi

    if [ "${MAGENTO_GERMAN_SETUP}" != "false" ]; then
        magento-composer require wilkesystems/magento2-german-setup:dev-master
        magento module:enable WilkeSystems_MageGermanSetup
        magento magesetup:setup:run de
        magento setup:upgrade
    fi

    if [ "${MAGENTO_CATALOG_IMPORT}" != "false" ]; then
        magento-composer require wilkesystems/magento2-catalog-import:dev-master
        magento module:enable WilkeSystems_CatalogImport
        magento setup:upgrade
        if [ -d /var/www/var/import -a -f /var/www/var/import/catalog.csv ]; then
            magento catalog:import --images_path=/var/www/var/import /var/www/var/import/catalog.csv
        fi
    fi

    return
}

function supervisor () {
    if [ -x /usr/bin/supervisord -a -f /etc/supervisor/supervisord.conf -a -d /etc/supervisor/conf.d ]; then
        if [ $(grep -c 'nodaemon=true ' /etc/supervisor/supervisord.conf) -ne 0 ]; then
            sed -i 's/^\(\[supervisord\]\)$/\1\nnodaemon=true/' /etc/supervisor/supervisord.conf
        fi

        if [ $(grep -c 'username = ' /etc/supervisor/supervisord.conf) -ne 1 ]; then
            sed -i "s/^\(\[unix_http_server\]\)$/\1\nusername = ${SUPERVISOR_USERNAME}\npassword = ${SUPERVISOR_PASSWORD}/" /etc/supervisor/supervisord.conf
            sed -i "s/^\(\[supervisorctl\]\)$/\1\nusername = ${SUPERVISOR_USERNAME}\npassword = ${SUPERVISOR_PASSWORD}/" /etc/supervisor/supervisord.conf
        else
            sed -i "s/^username = \(.*\)$/username = ${SUPERVISOR_USERNAME}/" /etc/supervisor/supervisord.conf
            sed -i "s/^password = \(.*\)$/password = ${SUPERVISOR_PASSWORD}/" /etc/supervisor/supervisord.conf
        fi

        echo -e "[inet_http_server]" > /etc/supervisor/conf.d/inet_http_server.conf
        echo -e "port = *:9001" >> /etc/supervisor/conf.d/inet_http_server.conf
        echo -e "username = ${SUPERVISOR_USERNAME}" >> /etc/supervisor/conf.d/inet_http_server.conf
        echo -e "password = ${SUPERVISOR_PASSWORD}" >> /etc/supervisor/conf.d/inet_http_server.conf

        if [ -x $(which cron) ]; then
            echo -e "[program:cron]" > /etc/supervisor/conf.d/cron.conf
            echo -e "porcess_name = cron" >> /etc/supervisor/conf.d/cron.conf
            echo -e "command=$(which cron) -f" >> /etc/supervisor/conf.d/cron.conf
            echo -e "autostart=true" >> /etc/supervisor/conf.d/cron.conf
            echo -e "autorestart=true" >> /etc/supervisor/conf.d/cron.conf
            echo -e "startretries=3" >> /etc/supervisor/conf.d/cron.conf
            echo -e "startsecs=0" >> /etc/supervisor/conf.d/cron.conf
            echo -e "stdout_logfile=/var/log/supervisor/cron-stdout.log" >> /etc/supervisor/conf.d/cron.conf
            echo -e "stderr_logfile=/var/log/supervisor/cron-stderr.log" >> /etc/supervisor/conf.d/cron.conf
            echo -e "stdout_logfile_maxbytes=0" >> /etc/supervisor/conf.d/cron.conf
            echo -e "stderr_logfile_maxbytes=0" >> /etc/supervisor/conf.d/cron.conf
        fi

        if [ -x $(which exim4) ]; then
            echo -e "[program:exim4]" > /etc/supervisor/conf.d/exim4.conf
            echo -e "porcess_name = exim4" >> /etc/supervisor/conf.d/exim4.conf
            echo -e "command=$(which exim4) -bd -v" >> /etc/supervisor/conf.d/exim4.conf
            echo -e "autostart=true" >> /etc/supervisor/conf.d/exim4.conf
            echo -e "autorestart=true" >> /etc/supervisor/conf.d/exim4.conf
            echo -e "redirect_stderr=true" >> /etc/supervisor/conf.d/exim4.conf
            echo -e "startretries=3" >> /etc/supervisor/conf.d/exim4.conf
            echo -e "startsecs=0" >> /etc/supervisor/conf.d/exim4.conf
            echo -e "stdout_logfile=/var/log/supervisor/exim4-stdout.log" >> /etc/supervisor/conf.d/exim4.conf
            echo -e "stderr_logfile=/var/log/supervisor/exim4-stderr.log" >> /etc/supervisor/conf.d/exim4.conf
            echo -e "stdout_logfile_maxbytes=0" >> /etc/supervisor/conf.d/exim4.conf
            echo -e "stderr_logfile_maxbytes=0" >> /etc/supervisor/conf.d/exim4.conf
        fi

        if [ -x $(which nginx) ]; then
            echo -e "[program:nginx]" > /etc/supervisor/conf.d/nginx.conf
            echo -e "process_name = nginx" >> /etc/supervisor/conf.d/nginx.conf
            echo -e "command=$(which nginx) -g 'daemon off;'" >> /etc/supervisor/conf.d/nginx.conf
            echo -e "autostart=true" >> /etc/supervisor/conf.d/nginx.conf
            echo -e "autorestart=true" >> /etc/supervisor/conf.d/nginx.conf
            echo -e "redirect_stderr=true" >> /etc/supervisor/conf.d/nginx.conf
            echo -e "startretries=3" >> /etc/supervisor/conf.d/nginx.conf
            echo -e "startsecs=0" >> /etc/supervisor/conf.d/nginx.conf
            echo -e "stdout_logfile=/var/log/supervisor/nginx-stdout.log" >> /etc/supervisor/conf.d/nginx.conf
            echo -e "stderr_logfile=/var/log/supervisor/nginx-stderr.log" >> /etc/supervisor/conf.d/nginx.conf
        fi

        if [ -x $(which php-fpm7.0) ]; then
            echo -e "[program:php]" > /etc/supervisor/conf.d/php-fpm7.0.conf
            echo -e "process_name = php" >> /etc/supervisor/conf.d/php-fpm7.0.conf
            echo -e "command=$(which php-fpm7.0) -F" >> /etc/supervisor/conf.d/php-fpm7.0.conf
            echo -e "autostart=true" >> /etc/supervisor/conf.d/php-fpm7.0.conf
            echo -e "autorestart=true" >> /etc/supervisor/conf.d/php-fpm7.0.conf
            echo -e "redirect_stderr=true" >> /etc/supervisor/conf.d/php-fpm7.0.conf
            echo -e "startretries=3" >> /etc/supervisor/conf.d/php-fpm7.0.conf
            echo -e "startsecs=0" >> /etc/supervisor/conf.d/php-fpm7.0.conf
            echo -e "stdout_logfile=/var/log/supervisor/php-stdout.log" >> /etc/supervisor/conf.d/php-fpm7.0.conf
            echo -e "stderr_logfile=/var/log/supervisor/php-stderr.log" >> /etc/supervisor/conf.d/php-fpm7.0.conf
        fi

        if [ -x $(which rsyslogd) ]; then
            echo -e "[program:syslog]" > /etc/supervisor/conf.d/rsyslogd.conf
            echo -e "porcess_name = syslog" >> /etc/supervisor/conf.d/rsyslogd.conf
            echo -e "command=$(which rsyslogd) -n" >> /etc/supervisor/conf.d/rsyslogd.conf
            echo -e "autostart=true" >> /etc/supervisor/conf.d/rsyslogd.conf
            echo -e "redirect_stderr=true" >> /etc/supervisor/conf.d/rsyslogd.conf
            echo -e "startretries=3" >> /etc/supervisor/conf.d/rsyslogd.conf
            echo -e "autorestart=true" >> /etc/supervisor/conf.d/rsyslogd.conf
            echo -e "startsecs=0" >> /etc/supervisor/conf.d/rsyslogd.conf
            echo -e "stdout_logfile=/var/log/supervisor/rsyslog-stdout.log" >> /etc/supervisor/conf.d/rsyslogd.conf
            echo -e "stderr_logfile=/var/log/supervisor/rsyslog-stderr.log" >> /etc/supervisor/conf.d/rsyslogd.conf
        fi

        unset ${!MAGENTO_*}

        exec supervisord -c /etc/supervisor/supervisord.conf -n -u root
    fi

    return
}
function print_usage ()
{
cat << EOF
Usage: "$(basename $0)" [Options]... [Command]...

  -h  --help     display this help and exit

      --debug    output debug information
      --version  output version information and exit

Commands:
  magento        magento
  restart        restart
  start          start
  status         status
  stop           stop

E-mail bug reports to: <developer@wilke.systems>.
EOF
exit
}

function print_auth ()
{
cat << EOF
Authentication Keys Required

The repo.magento.com repository is where Magento 2 and third-party Composer 
packages are stored and requires authentication. Use your Magento Marketplace 
account to generate a pair of 32-character authentication keys to access the 
repository.

To create authentication keys:

1. Log in to the Magento Marketplace.
   If you don’t have an account, click Register.

2. Click your account name in the top-right of the page
   and select My Profile.

3. Click Access Keys in the Marketplace tab.

4. Click Create a New Access Key. Enter a specific name for the keys
   (e.g., the name of the developer receiving the keys) and click OK.

5. New public and private keys are now associated with your account
   that you can click to copy. Save this information or keep the page open
   when working with your Magento project. Use the Public key as your
   user name and the Private key as your password.

EOF
read -n 1 -s INPUT
exit
}

function print_version ()
{
cat << EOF

MIT License

Copyright (c) 2017 Wilke.Systems

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

EOF
exit
}

main "$@"

exit