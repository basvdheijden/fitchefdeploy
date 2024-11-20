FROM docker:20.10.8-dind-alpine3.13

RUN apk add python3 python3-dev gcc musl-dev py3-pip curl rsync git nodejs npm && \
  wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz && \
  tar -zxf google-cloud-* && \
  ./google-cloud-sdk/install.sh && \
  ln -s $(pwd)google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud && \
  ln -s $(pwd)google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil && \
  ln -s $(pwd)google-cloud-sdk/bin/kubectl /usr/local/bin/kubectl && \
  gcloud components install kubectl docker-credential-gcr && \
  curl --location -o /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && \
  chmod +x /usr/local/bin/jq && \
  pip3 install --no-cache-dir -U crcmod;
