FROM docker:27.3.1-dind-alpine3.20

ENV PYTHON_VERSION 3.10.15
ENV PYTHON_SHA256 aab0950817735172601879872d937c1e4928a57c409ae02369ec3d91dccebe79

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

RUN set -eux; \
  apk add --no-cache \
    ca-certificates \
    tzdata \
  ;

ENV GPG_KEY A035C8C19219BA821ECEA86B64E628F8D684696D

RUN set -eux; \
  \
  apk add --no-cache --virtual .build-deps \
    gnupg \
    tar \
    xz \
    \
    bluez-dev \
    bzip2-dev \
    dpkg-dev dpkg \
    findutils \
    gcc \
    gdbm-dev \
    libc-dev \
    libffi-dev \
    libnsl-dev \
    libtirpc-dev \
    linux-headers \
    make \
    ncurses-dev \
    openssl-dev \
    pax-utils \
    readline-dev \
    sqlite-dev \
    tcl-dev \
    tk \
    tk-dev \
    util-linux-dev \
    xz-dev \
    zlib-dev \
  ; \
  \
  wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"; \
  echo "$PYTHON_SHA256 *python.tar.xz" | sha256sum -c -; \
  wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc"; \
  GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
  gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$GPG_KEY"; \
  gpg --batch --verify python.tar.xz.asc python.tar.xz; \
  gpgconf --kill all; \
  rm -rf "$GNUPGHOME" python.tar.xz.asc; \
  mkdir -p /usr/src/python; \
  tar --extract --directory /usr/src/python --strip-components=1 --file python.tar.xz; \
  rm python.tar.xz; \
  \
  cd /usr/src/python; \
  gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
  ./configure \
    --build="$gnuArch" \
    --enable-loadable-sqlite-extensions \
    --enable-option-checking=fatal \
    --enable-shared \
    --with-lto \
    --with-ensurepip \
  ; \
  nproc="$(nproc)"; \
# set thread stack size to 1MB so we don't segfault before we hit sys.getrecursionlimit()
# https://github.com/alpinelinux/aports/commit/2026e1259422d4e0cf92391ca2d3844356c649d0
  EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000"; \
  LDFLAGS="${LDFLAGS:--Wl},--strip-all"; \
  make -j "$nproc" \
    "EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
    "LDFLAGS=${LDFLAGS:-}" \
  ; \
# https://github.com/docker-library/python/issues/784
# prevent accidental usage of a system installed libpython of the same version
  rm python; \
  make -j "$nproc" \
    "EXTRA_CFLAGS=${EXTRA_CFLAGS:-}" \
    "LDFLAGS=${LDFLAGS:--Wl},-rpath='\$\$ORIGIN/../lib'" \
    python \
  ; \
  make install; \
  \
  cd /; \
  rm -rf /usr/src/python; \
  \
  find /usr/local -depth \
    \( \
      \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
      -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name 'libpython*.a' \) \) \
    \) -exec rm -rf '{}' + \
  ; \
  \
  find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec scanelf --needed --nobanner --format '%n#p' '{}' ';' \
    | tr ',' '\n' \
    | sort -u \
    | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    | xargs -rt apk add --no-network --virtual .python-rundeps \
  ; \
  apk del --no-network .build-deps; \
  \
  export PYTHONDONTWRITEBYTECODE=1; \
  python3 --version; \
  \
  pip3 install \
    --disable-pip-version-check \
    --no-cache-dir \
    --no-compile \
    'setuptools==65.5.1' \
    wheel \
  ; \
  pip3 --version

# make some useful symlinks that are expected to exist ("/usr/local/bin/python" and friends)
RUN set -eux; \
  for src in idle3 pip3 pydoc3 python3 python3-config; do \
    dst="$(echo "$src" | tr -d 3)"; \
    [ -s "/usr/local/bin/$src" ]; \
    [ ! -e "/usr/local/bin/$dst" ]; \
    ln -svT "$src" "/usr/local/bin/$dst"; \
  done

RUN apk add mysql-client gcc musl-dev curl rsync git nodejs npm && \
  npm install -g yarn && \
  wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz && \
  tar -zxf google-cloud-* && \
  ./google-cloud-sdk/install.sh && \
  ln -s $(pwd)google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud && \
  ln -s $(pwd)google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil && \
  ln -s $(pwd)google-cloud-sdk/bin/kubectl /usr/local/bin/kubectl && \
  gcloud components install kubectl docker-credential-gcr && \
  curl --location -o /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && \
  chmod +x /usr/local/bin/jq;
