FROM tomcat:10-jdk11-temurin

LABEL maintainer="Sarafrika <info@sarafrika.com>"

# Environment variables
ENV JAVA_OPTS="-server -Xms1G -Xmx4G -XX:+UseG1GC -XX:+UseCompressedOops -XX:+DisableExplicitGC"
ENV CATALINA_OPTS="-Dsakai.home=/usr/local/sakai"
ENV MAVEN_OPTS="-Xms512m -Xmx1024m"

# Install required packages
RUN apt-get update && \
    apt-get install -y \
    wget \
    unzip \
    maven \
    git \
    gettext \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /usr/local/sakai/properties

# Download the specific Sakai release
WORKDIR /tmp
ARG SAKAI_VERSION=23.0
RUN git clone -b ${SAKAI_VERSION} --depth 1 https://github.com/sakaiproject/sakai.git

# Build Sakai using Maven with JDK 11
WORKDIR /tmp/sakai
RUN mvn clean install -Dmaven.test.skip=true -Djava.net.preferIPv4Stack=true

# Find and copy the built webapps to Tomcat
# First check if they're in the expected location
RUN find /tmp/sakai -name "*.war" -o -name "portal" -o -name "portal.war" | grep -v target

# Handle different Sakai build structures
RUN mkdir -p $CATALINA_HOME/webapps && \
    if [ -d "/tmp/sakai/webapps" ]; then \
        cp -R /tmp/sakai/webapps/* $CATALINA_HOME/webapps/ || echo "No files in /tmp/sakai/webapps"; \
    fi && \
    # Try to find built WARs in target directories and deploy them
    find /tmp/sakai -name "*.war" | grep "target" | xargs -I {} cp {} $CATALINA_HOME/webapps/ || echo "No WAR files found"

# Download MariaDB JDBC connector
WORKDIR /tmp
RUN wget https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.3.2/mariadb-java-client-3.3.2.jar \
    && mv mariadb-java-client-3.3.2.jar $CATALINA_HOME/lib/

# Create a directory for config templates and final configs
RUN mkdir -p /usr/local/sakai/templates
RUN mkdir -p /usr/local/sakai/properties

# Copy configuration templates from repository
COPY config/sakai.properties /usr/local/sakai/templates/sakai.properties.template
COPY config/local.properties /usr/local/sakai/templates/local.properties.template
COPY tomcat/server.xml $CATALINA_HOME/conf/

# Set proper permissions
RUN chmod -R 755 $CATALINA_HOME/webapps/
RUN mkdir -p $CATALINA_HOME/sakai && \
    chmod -R 777 $CATALINA_HOME/sakai

# List what's in webapps for debugging
RUN ls -la $CATALINA_HOME/webapps/

# Expose port
EXPOSE 8080

# Create a startup script to process templates with environment variables
RUN echo '#!/bin/bash\n\
# Process sakai.properties template with environment variables\n\
envsubst < /usr/local/sakai/templates/sakai.properties.template > /usr/local/sakai/properties/sakai.properties\n\
envsubst < /usr/local/sakai/templates/local.properties.template > /usr/local/sakai/properties/local.properties\n\
\n\
# Start Tomcat\n\
exec catalina.sh run\n\
' > /usr/local/bin/startup.sh

RUN chmod +x /usr/local/bin/startup.sh

# Start with the template processing script
CMD ["/usr/local/bin/startup.sh"]