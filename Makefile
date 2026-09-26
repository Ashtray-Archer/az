PREFIX ?= /usr/local
DESTDIR ?=
SHELL ?= /bin/sh

.PHONY: test test-sms install

test:
	sh test/grease-boundary-test.sh
	bash test/az-test.sh
	bash test/abe-test.sh
	bash test/aa-test.sh
	bash test/zillow-test.sh
	sh -n bin/idric_sms_service
	sh -n test/sms-service-test.sh

test-sms:
	sh test/sms-service-test.sh

install:
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -m 0755 bin/az "$(DESTDIR)$(PREFIX)/bin/az"
	install -m 0755 bin/abe "$(DESTDIR)$(PREFIX)/bin/abe"
	install -m 0755 bin/aa "$(DESTDIR)$(PREFIX)/bin/aa"
	install -m 0755 bin/zillow "$(DESTDIR)$(PREFIX)/bin/zillow"
	install -m 0755 bin/idric_sms_service "$(DESTDIR)$(PREFIX)/bin/idric_sms_service"
