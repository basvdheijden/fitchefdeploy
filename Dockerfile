FROM alpine:3.13

RUN apk add python3 curl && \
  wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-366.0.0-linux-x86_64.tar.gz && \
  tar -zxf google-cloud-* && \
  ./google-cloud-sdk/install.sh;

RUN ln -s $(pwd)/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud
RUN gcloud components install kubectl docker-credential-gcr