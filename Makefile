.DEFAULT_GOAL := protos

LOCAL_CONF = ${CURDIR}/conf/local.conf

PROTOS = protos
CONF   = conf
LOGS   = ${CURDIR}/log
SCRIPT = ${CURDIR}/script
CONF_DIR = ${CURDIR}/conf
MODULES = ${shell find lib -name '*.pm'}
REVISION = ${shell git rev-list HEAD -1}
MODE = ${shell perl -e "print((do '${LOCAL_CONF}')->{'mode'})"}

mode:
	@echo "${MODE}"

install:
	@${CURDIR}/install.newbox.sh
	@sudo cp /etc/letsencrypt/live/${STATIC_HOST}/privkey.pem .ssl/privkey.pem
	@sudo cp /etc/letsencrypt/live/${STATIC_HOST}/fullchain.pem .ssl/fullchain.pem

logs:
	@tail -F ${LOGS}/*.log

check:
	find lib -name '*.pm' -exec perl -I${CURDIR}/lib -I${CURDIR}/extlib -Mlocal::lib=${CURDIR}/local -c {} \;
checktest:
	for module in $(MODULES); do \
		if perl -I${CURDIR}/lib -I${CURDIR}/extlib -Mlocal::lib=${CURDIR}/local -c $$module ; then \
			echo OK; \
		else \
			exit 2; \
		fi; \
	done
test:
	@script/app test -v $(filter-out $@,$(MAKECMDGOALS))

start: protos stop
	@./start

stop: dirs
	@./stop

protos: dirs
	@protos/make.pl

dirs:
	@mkdir -p ${LOGS}
	@mkdir -p ${SCRIPT}
	@mkdir -p ${CONF_DIR}
	@mkdir -p .ssl

info:
	@perl -MData::Dumper -e 'warn Dumper \%ENV'

update:
	@git pull

upgrade:
	carton install --deployment

fullupgrade: upgrade

up: update upgrade protos

export
