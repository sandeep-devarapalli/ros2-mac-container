FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=jazzy
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
ENV CYCLONEDDS_URI=file:///opt/ros2-mac-container/cyclonedds.xml

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg locales lsb-release software-properties-common sudo \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") main" \
    > /etc/apt/sources.list.d/ros2.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    dbus-x11 iproute2 iputils-ping kde-plasma-desktop konsole net-tools \
    python3-argcomplete python3-colcon-common-extensions \
    ros-jazzy-compressed-image-transport ros-jazzy-desktop ros-jazzy-image-transport \
    ros-jazzy-rmw-cyclonedds-cpp ros-jazzy-rmw-zenoh-cpp ros-jazzy-rosbridge-server xorgxrdp xrdp \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash ros \
    && echo "ros:ros" | chpasswd \
    && usermod -aG sudo ros \
    && echo "ros ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ros \
    && chmod 0440 /etc/sudoers.d/ros \
    && echo "startplasma-x11" > /home/ros/.xsession \
    && chown ros:ros /home/ros/.xsession

COPY config/cyclonedds.xml /opt/ros2-mac-container/cyclonedds.xml
COPY config/zenoh-router.json5 /opt/ros2-mac-container/zenoh-router.json5
COPY scripts/container-entrypoint.sh /usr/local/bin/container-entrypoint.sh

RUN chmod +x /usr/local/bin/container-entrypoint.sh \
    && echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /home/ros/.bashrc \
    && echo "export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp" >> /home/ros/.bashrc \
    && echo "export CYCLONEDDS_URI=file:///opt/ros2-mac-container/cyclonedds.xml" >> /home/ros/.bashrc \
    && chown ros:ros /home/ros/.bashrc

EXPOSE 3389/tcp 8765/tcp 7447/tcp

ENTRYPOINT ["/usr/local/bin/container-entrypoint.sh"]
