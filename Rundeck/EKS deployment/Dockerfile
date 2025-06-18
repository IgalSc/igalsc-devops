FROM rundeck/rundeck:5.0.2

USER root

# Install Python, pip, and AWS CLI v2
RUN apt-get update && \
    apt-get install -y python3 python3-pip unzip curl jq && \
    pip3 install --upgrade pip boto3

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Add Python requirements and scripts
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install -r /tmp/requirements.txt

COPY scripts/ /home/rundeck/scripts/
RUN chown -R rundeck:rundeck /home/rundeck/scripts

USER rundeck