FROM fedora:28
##inspired by https://pagure.io/389-ds-base/issue/50197
EXPOSE 389 636
ENV container docker

ARG VERSION=1.4.1.2

RUN mkdir -p /usr/local/src

RUN dnf upgrade -y &&\
    dnf install -y wget git

RUN wget https://pagure.io/389-ds-base/archive/389-ds-base-${VERSION}/389-ds-base-389-ds-base-${VERSION}.tar.gz
RUN tar xf 389-ds-base-389-ds-base-${VERSION}.tar.gz -C /usr/local/src
RUN mv /usr/local/src/389-ds-base-389-ds-base-${VERSION} /usr/local/src/389-ds-base

WORKDIR /usr/local/src
RUN ls -alh

RUN grep -E "^(Build)?Requires" 389-ds-base/rpm/389-ds-base.spec.in | grep -v -E '(name|MODULE)' | awk '{ print $2 }' | sed 's/%{python3_pkgversion}/3/g' | grep -v "^/" | grep -v pkgversion | sort | uniq | tr '\n' ' '

RUN dnf upgrade -y && \
    dnf install --setopt=strict=False -y \
        @buildsys-build rpm-build make bzip2 git wget rsync \
        `grep -E "^(Build)?Requires" 389-ds-base/rpm/389-ds-base.spec.in | grep -v -E '(name|MODULE)' | awk '{ print $2 }' | sed 's/%{python3_pkgversion}/3/g' | grep -v "^/" | grep -v pkgversion | sort | uniq | tr '\n' ' '` && \
    dnf clean all


### CHANGE THIS TO A ./configure and build that way.

RUN cd 389-ds-base && \
    PERL_ON=0 RUST_ON=1 make -f rpm.mk rpms

RUN dnf install -y 389-ds-base/dist/rpms/*389*.rpm && \
    dnf clean all

# Create the example setup inf. It's valid for containers!
# Build the instance from the new installer tools.

COPY dscontainer /usr/sbin/dscontainer

EXPOSE 3389 3636
RUN mkdir -p /data/config && \
    mkdir -p /data/ssca && \
    mkdir -p /data/var/run && \
    ln -s /data/var/run /var/run/dirsrv && \
    ln -s /data/config /etc/dirsrv/slapd-localhost && \
    ln -s /data/ssca /etc/dirsrv/ssca && \
    chown -R dirsrv /data

#CMD ["/usr/sbin/dscontainer", "-r"]
CMD ["/usr/sbin/ns-slapd", "-d", "0", "-D", "/etc/dirsrv/slapd-localhost", "-i", "/var/run/dirsrv/slapd-localhost.pid"]

