# Dockerfile for ELK stack
# Elasticsearch 2.0.0, Logstash 2.0.0, Kibana 4.2.0

# Build with:
# docker build -t <repo-user>/elk .

# Run with:
# docker run -p 5601:5601 -p 9200:9200 -p 5000:5000 -it --name elk <repo-user>/elk

FROM phusion/baseimage
MAINTAINER Sebastien Pujadas http://pujadas.net
ENV REFRESHED_AT 2015-11-05

###############################################################################
#                                INSTALLATION
###############################################################################

### install Elasticsearch

RUN apt-get update -qq \
 && apt-get install -qqy curl

RUN curl http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add -
RUN echo deb http://packages.elasticsearch.org/elasticsearch/2.x/debian stable main > /etc/apt/sources.list.d/elasticsearch-2.x.list

RUN apt-get update -qq \
 && apt-get install -qqy \
		elasticsearch \
		openjdk-7-jdk \
 && apt-get clean


### install Logstash

ENV LOGSTASH_HOME /opt/logstash
ENV LOGSTASH_PACKAGE logstash-2.0.0.tar.gz

RUN mkdir ${LOGSTASH_HOME} \
 && curl -O https://download.elasticsearch.org/logstash/logstash/${LOGSTASH_PACKAGE} \
 && tar xzf ${LOGSTASH_PACKAGE} -C ${LOGSTASH_HOME} --strip-components=1 \
 && rm -f ${LOGSTASH_PACKAGE} \
 && groupadd -r logstash \
 && useradd -r -s /usr/sbin/nologin -d ${LOGSTASH_HOME} -c "Logstash service user" -g logstash logstash \
 && mkdir -p /var/log/logstash /etc/logstash/conf.d \
 && chown -R logstash:logstash ${LOGSTASH_HOME} /var/log/logstash

ADD ./logstash-init /etc/init.d/logstash
RUN sed -i -e 's#^LS_HOME=$#LS_HOME='$LOGSTASH_HOME'#' /etc/init.d/logstash \
 && chmod +x /etc/init.d/logstash


### install Kibana

ENV KIBANA_HOME /opt/kibana
ENV KIBANA_PACKAGE kibana-4.2.0-linux-x64.tar.gz

RUN mkdir ${KIBANA_HOME} \
 && curl -O https://download.elasticsearch.org/kibana/kibana/${KIBANA_PACKAGE} \
 && tar xzf ${KIBANA_PACKAGE} -C ${KIBANA_HOME} --strip-components=1 \
 && rm -f ${KIBANA_PACKAGE} \
 && groupadd -r kibana \
 && useradd -r -s /usr/sbin/nologin -d ${KIBANA_HOME} -c "Kibana service user" -g kibana kibana \
 && chown -R kibana:kibana ${KIBANA_HOME}

ADD ./kibana-init /etc/init.d/kibana
RUN sed -i -e 's#^KIBANA_HOME=$#KIBANA_HOME='$KIBANA_HOME'#' /etc/init.d/kibana \
 && chmod +x /etc/init.d/kibana


###############################################################################
#                               CONFIGURATION
###############################################################################

### configure Elasticsearch

ADD ./elasticsearch.yml /etc/elasticsearch/elasticsearch.yml

ENV ES_HOME /usr/share/elasticsearch
WORKDIR ${ES_HOME}

RUN bin/plugin install royrusso/elasticsearch-HQ
RUN bin/plugin install discovery-multicast
RUN bin/plugin install analysis-icu
RUN bin/plugin install analysis-phonetic
RUN bin/plugin install http://dl.bintray.com/content/imotov/elasticsearch-plugins/org/elasticsearch/elasticsearch-analysis-morphology/2.1.0/elasticsearch-analysis-morphology-2.1.0.zip
RUN bin/plugin install lmenezes/elasticsearch-kopf/{2.0|2.1.1}
RUN bin/plugin install https://github.com/NLPchina/elasticsearch-sql/releases/download/2.1.0/elasticsearch-sql-2.1.0.zip
RUN bin/plugin install http://xbib.org/repository/org/xbib/elasticsearch/plugin/elasticsearch-analysis-decompound/2.1.0.0/elasticsearch-analysis-decompound-2.1.0.0-plugin.zip
RUN bin/plugin install http://xbib.org/repository/org/xbib/elasticsearch/plugin/elasticsearch-analysis-standardnumber/2.0.0-beta2.0/elasticsearch-analysis-standardnumber-2.0.0-beta2.0-plugin.zip
RUN bin/plugin install lukas-vlcek/bigdesk
RUN bin/plugin install http://xbib.org/repository/org/xbib/elasticsearch/plugin/elasticsearch-langdetect/2.1.0.0/elasticsearch-langdetect-2.1.0.0-plugin.zip
RUN bin/plugin install org.codelibs/elasticsearch-reindexing/2.1.0
RUN bin/plugin install org.codelibs/elasticsearch-analyze-api/2.1.0

## MAybe in future we needto identify numbers
## bin/plugin install http://xbib.org/repository/org/xbib/elasticsearch/plugin/elasticsearch-analysis-standardnumber/2.0.0-beta2.0/elasticsearch-analysis-standardnumber-2.0.0-beta2.0-plugin.zip

### configure Logstash

# cert/key
RUN mkdir -p /etc/pki/tls/certs && mkdir /etc/pki/tls/private
ADD ./logstash-forwarder.crt /etc/pki/tls/certs/logstash-forwarder.crt
ADD ./logstash-forwarder.key /etc/pki/tls/private/logstash-forwarder.key

# filters
ADD ./01-lumberjack-input.conf /etc/logstash/conf.d/01-lumberjack-input.conf
ADD ./10-syslog.conf /etc/logstash/conf.d/10-syslog.conf
ADD ./11-nginx.conf /etc/logstash/conf.d/11-nginx.conf
ADD ./30-lumberjack-output.conf /etc/logstash/conf.d/30-lumberjack-output.conf

# patterns
ADD ./nginx.pattern ${LOGSTASH_HOME}/patterns/nginx
RUN chown -R logstash:logstash ${LOGSTASH_HOME}/patterns


###############################################################################
#                                   START
###############################################################################

ADD ./start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 5601 9200 9300 5000
VOLUME /var/lib/elasticsearch

CMD [ "/usr/local/bin/start.sh" ]
