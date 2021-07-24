FROM rundeck/rundeck:3.4.1

FROM adoptopenjdk/openjdk11:alpine

RUN apk add --no-cache --update acl ansible bash curl gnupg git openssh tzdata rsync sshpass sudo uuidgen wget \
    && adduser -G root -s /bin/bash -h /home/rundeck -g "" -D rundeck \
    && chmod 0775 /home/rundeck \
    && passwd -d rundeck \
    && addgroup rundeck wheel \
    && echo | sudo -u rundeck ssh-keygen -N '' -t rsa -b 4096 \
    && chmod g+w /etc/passwd

ENV REMCO_VERSION 0.12.1
ENV TINI_VERSION v0.19.0

RUN wget -O /remco.zip https://github.com/HeavyHorst/remco/releases/download/v${REMCO_VERSION}/remco_${REMCO_VERSION}_linux_amd64.zip \
    && unzip /remco.zip \
    && mv -v /remco_linux /usr/local/bin/remco \
    && rm -f /remco.zip

RUN wget -O /tini https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-amd64 \
    && wget -O /tini.asc https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-amd64.asc \
    && export GNUPGHOME="$(mktemp -d)" &&  echo "disable-ipv6" >> "${GNUPGHOME}/dirmngr.conf" \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 \
    && gpg --batch --verify /tini.asc /tini \
    && chmod +x /tini

WORKDIR /home/rundeck

COPY --from=0 /home/rundeck/rundeck.war rundeck.war

RUN sudo -u rundeck java -jar rundeck.war --installonly \
    && sudo -u rundeck mkdir libext \
    && sudo -u rundeck git clone https://github.com/rundeck/rundeck.git -b v3.4.1 --depth 1 \
    && cp -av rundeck/docker/official/remco /etc/remco \
    && cp -av rundeck/docker/official/lib docker-lib \
    && cp -av rundeck/docker/official/etc etc \
    && chmod -R g+w libext server user-assets var etc \
    && rm -rf rundeck

USER rundeck
VOLUME ["/home/rundeck/server/data"]

EXPOSE 4440
ENTRYPOINT [ "/tini", "--", "docker-lib/entry.sh" ]