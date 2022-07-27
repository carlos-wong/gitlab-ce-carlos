ARG DOCKER_VERSION=20.10.14
ARG CHROME_VERSION=101
ARG QA_BUILD_TARGET=qa

FROM registry.gitlab.com/gitlab-org/gitlab-build-images/debian-bullseye-ruby-2.7:bundler-2.3-git-2.33-lfs-2.9-chrome-${CHROME_VERSION}-docker-${DOCKER_VERSION}-gcloud-383-kubectl-1.23 AS qa
LABEL maintainer="GitLab Quality Department <quality@gitlab.com>"

ENV DEBIAN_FRONTEND="noninteractive"
# Override config path to make sure local config doesn't override it when building image locally
ENV BUNDLE_APP_CONFIG=/home/gitlab/.bundle
# Use webdriver preinstalled in the base image
ENV WD_INSTALL_DIR=/usr/local/bin

##
# Install system libs
#
RUN apt-get update; \
    apt-get install -y xvfb unzip; \
    apt-get -yq autoremove; \
    apt-get clean -yqq; \
    rm -rf /var/lib/apt/lists/*

##
# Install root certificate
#
RUN mkdir -p /usr/share/ca-certificates/gitlab
ADD ./qa/tls_certificates/authority/ca.crt /usr/share/ca-certificates/gitlab/
RUN echo 'gitlab/ca.crt' >> /etc/ca-certificates.conf
RUN chmod -R 644 /usr/share/ca-certificates/gitlab && update-ca-certificates

WORKDIR /home/gitlab/qa

##
# Install qa dependencies or fetch from cache if unchanged
#
COPY ./qa/Gemfile* /home/gitlab/qa/
RUN bundle config set --local without development \
    && bundle install --retry=3

COPY ./config/initializers/0_inject_enterprise_edition_module.rb /home/gitlab/config/initializers/
# Copy VERSION to ensure the COPY succeeds to copy at least one file since ee/app/models/license.rb isn't present in FOSS
# The [b] part makes ./ee/app/models/license.r[b] a pattern that is allowed to return no files (which is the case in FOSS)
COPY VERSION ./ee/app/models/license.r[b] /home/gitlab/ee/app/models/
COPY VERSION ./ee/config/feature_flag[s] /home/gitlab/ee/config/feature_flags/
COPY ./config/feature_flags /home/gitlab/config/feature_flags
COPY ./config/bundler_setup.rb /home/gitlab/config/
COPY ./lib/gitlab_edition.rb /home/gitlab/lib/
COPY ./lib/gitlab/utils.rb /home/gitlab/lib/gitlab/
COPY ./INSTALLATION_TYPE ./VERSION /home/gitlab/

COPY ./qa /home/gitlab/qa

ENTRYPOINT ["bin/test"]

# Add JH files when pass the parameter: `--build-arg QA_BUILD_TARGET=jhqa`
FROM qa AS jhqa
ONBUILD COPY ./jh/qa /home/gitlab/jh/qa
ONBUILD COPY ./jh/lib /home/gitlab/jh/lib
ONBUILD COPY ./jh/config/feature_flags /home/gitlab/jh/config/feature_flags

FROM $QA_BUILD_TARGET
