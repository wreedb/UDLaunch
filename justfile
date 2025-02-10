esc_blue     := '\e[1;34m'
esc_yellow   := '\e[1;33m'
esc_green    := '\e[1;32m'
reset        := '\e[0m'
releaseflags := '-march=native -mtune=native -pipe -O3 -flto'

default: build

build:
    @echo -e "{{esc_blue}}builing{{reset}}: debug mode"
    v -debug . -o udlaunch

release:
    @echo -e "{{esc_green}}building{{reset}}: release mode"
    env -u VFLAGS v -cc clang -prod -no-prod-options -cflags "{{releaseflags}}" . -o udlaunch

check:
    @echo -e "{{esc_yellow}}checking{{reset}}"
    v -check .