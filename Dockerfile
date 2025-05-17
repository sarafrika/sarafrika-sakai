# Stage 1: Build Sakai
FROM maven:3.9-eclipse-temurin-11 AS builder

LABEL stage=builder

# Set Maven options for build
ENV MAVEN_OPTS="-Xms512m -Xmx1024m"

# Clone and build Sakai
WORKDIR /tmp
ARG SAKAI_VERSION=23.3
RUN git clone -b ${SAKAI_VERSION} --depth 1 https://github.com/sakaiproject/sakai.git

WORKDIR /tmp/sakai
# Build Sakai with Maven
RUN mvn clean install -Dmaven.test.skip=true -Djava.net.preferIPv4Stack=true

# Stage 2: Runtime environment
FROM tomcat:10-jdk11-temurin

LABEL maintainer="Sarafrika <info@sarafrika.com>"

# Environment variables for Java and Tomcat
ENV JAVA_OPTS="-server -Xms1G -Xmx4G -XX:+UseG1GC -XX:+UseCompressedOops -XX:+DisableExplicitGC"
ENV CATALINA_OPTS="-Dsakai.home=/usr/local/sakai"

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gettext \
    && rm -rf /var/lib/apt/lists/*

# Create Sakai directories
RUN mkdir -p /usr/local/sakai/properties /usr/local/sakai/templates

# Copy built webapps from builder stage
COPY --from=builder /tmp/sakai/webapps/ $CATALINA_HOME/webapps/

# If webapps are in 'target' directories instead, this would handle that case
RUN mkdir -p $CATALINA_HOME/webapps/
COPY --from=builder /tmp/sakai/*/target/*.war $CATALINA_HOME/webapps/ 2>/dev/null || true

# Download MariaDB JDBC connector
ADD https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.3.2/mariadb-java-client-3.3.2.jar $CATALINA_HOME/lib/

# Copy configuration templates
COPY config/sakai.properties /usr/local/sakai/templates/sakai.properties.template
COPY config/local.properties /usr/local/sakai/templates/local.properties.template
COPY tomcat/server.xml $CATALINA_HOME/conf/

# Set proper permissions
RUN chmod -R 755 $CATALINA_HOME/webapps/ && \
    mkdir -p $CATALINA_HOME/sakai && \
    chmod -R 777 $CATALINA_HOME/sakai

# Expose Tomcat port
EXPOSE 8080

# Create startup script to process templates with environment variables
RUN echo '#!/bin/bash\n\
# Process properties templates with environment variables\n\
envsubst < /usr/local/sakai/templates/sakai.properties.template > /usr/local/sakai/properties/sakai.properties\n\
envsubst < /usr/local/sakai/templates/local.properties.template > /usr/local/sakai/properties/local.properties\n\
\n\
# Start Tomcat\n\
exec catalina.sh run\n\
' > /usr/local/bin/startup.sh && chmod +x /usr/local/bin/startup.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/portal || exit 1

# Start with the template processing script
CMD ["/usr/local/bin/startup.sh"]