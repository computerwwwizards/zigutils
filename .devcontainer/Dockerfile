

FROM ubuntu:latest



ENV SHELL=/bin/zsh

RUN apt-get update && apt-get install -y \
    zip \
    unzip \
    git \
    curl \
    zsh \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

ENV PORT=3000

USER ubuntu

WORKDIR /home/ubuntu

# Install Oh My Zsh for zsh (non-interactive)
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended
RUN curl -fsSL https://get.pnpm.io/install.sh | sh 
RUN curl -fsSL https://fnm.vercel.app/install | zsh
RUN curl -fsSL https://ziglang.org/download/0.15.2/zig-x86_64-linux-0.15.2.tar.xz -o /home/ubuntu/zig.tar.xz \
    && mkdir -p /home/ubuntu/.local/zig \
    && tar -xf /home/ubuntu/zig.tar.xz -C /home/ubuntu/.local/zig --strip-components=1 \
    && echo 'export PATH=$PATH:/home/ubuntu/.local/zig' >> /home/ubuntu/.zshrc \
    && rm /home/ubuntu/zig.tar.xz

CMD ["tail", "-f", "/dev/null"]