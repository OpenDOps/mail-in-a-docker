FROM nginx:alpine3.20

ARG WGET_VERSION="1.24.5-r0"
ARG UNZIP_VERSION="6.0-r14"
ARG LIBIDN2_VERSION="1.42-r0"
ARG IDN2_UTILS_VERSION="2.3.7-r0"

# Install required tools
RUN apk add --no-cache wget=${WGET_VERSION} \
            unzip=${UNZIP_VERSION} \
            libidn=${LIBIDN2_VERSION} \
            idn2-utils=${IDN2_UTILS_VERSION}

# Create directory for assets
RUN mkdir -p /mailinabox/vendor/assets

# Download and verify jQuery
RUN echo "Downloading jQuery..." && \
    wget --progress=dot:giga -O /mailinabox/vendor/assets/jquery.min.js \
      https://code.jquery.com/jquery-2.2.4.min.js && \
    echo "69bb69e25ca7d5ef0935317584e6153f3fd9a88c  /mailinabox/vendor/assets/jquery.min.js" | sha1sum -cw -

# Download and verify Bootstrap
RUN echo "Downloading Bootstrap..." && \
    wget --progress=dot:giga -O /tmp/bootstrap.zip \
      https://github.com/twbs/bootstrap/releases/download/v3.4.1/bootstrap-3.4.1-dist.zip && \
    echo "0bb64c67c2552014d48ab4db81c2e8c01781f580  /tmp/bootstrap.zip" | sha1sum -cw - && \
    unzip -q /tmp/bootstrap.zip -d /mailinabox/vendor/assets && \
    mv /mailinabox/vendor/assets/bootstrap-3.4.1-dist /mailinabox/vendor/assets/bootstrap && \
    rm -f /tmp/bootstrap.zip

# Verify structure
RUN echo "Verifying asset structure..." && \
    ls -la /mailinabox/vendor/assets/ && \
    ls -la /mailinabox/vendor/assets/bootstrap/ && \
    ls -la /mailinabox/vendor/assets/bootstrap/css/ && \
    test -f /mailinabox/vendor/assets/bootstrap/css/bootstrap.min.css && \
    echo "✓ bootstrap.min.css found" || (echo "✗ bootstrap.min.css NOT found" && exit 1) && \
    echo "Assets downloaded successfully"

# Create directories for entrypoint and assets
RUN mkdir -p /opt/entrypoint /opt/mailinabox-assets

COPY mailinabox-assets/ /opt/mailinabox-assets/
COPY web/assets/setup/entrypoint.sh /opt/entrypoint/setup_web_runtime.sh

# Make entrypoint script executable and verify it exists
RUN chmod +x /opt/entrypoint/setup_web_runtime.sh && \
    ls -la /opt/entrypoint/setup_web_runtime.sh && \
    test -f /opt/entrypoint/setup_web_runtime.sh || (echo "ERROR: Entrypoint script not found!" && exit 1)

# Create directory for generated files
RUN mkdir -p /var/lib/mailinabox

# Set default environment variables if not provided
ENV MTA_STS_MODE=enforce

# Set the working directory to the assets location
WORKDIR /mailinabox/vendor/assets

# Run entrypoint script which will start nginx
CMD ["/opt/entrypoint/setup_web_runtime.sh"]
