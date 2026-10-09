# R
FROM rocker/r-ver:4.5.2

ENV DEBIAN_FRONTEND=noninteractive \
    MAKEFLAGS=-j2

# tools to compile R packages and cmdstan.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git curl ca-certificates \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libfontconfig1-dev libfreetype6-dev libpng-dev \
    libjpeg-dev libtiff-dev libharfbuzz-dev libfribidi-dev \
    libgit2-dev libicu-dev \
    && rm -rf /var/lib/apt/lists/*

# python
COPY --from=ghcr.io/astral-sh/uv:0.12.19 /uv /uvx /bin/
RUN uv python install 3.14.3 && uv venv --python 3.14.3 /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

WORKDIR /app

COPY requirements.txt ./
RUN uv pip install --python /opt/venv/bin/python -r requirements.txt

# add renv
RUN Rscript -e 'install.packages("renv", repos="https://cloud.r-project.org")'
COPY .Rprofile renv.lock ./
COPY renv/activate.R renv/activate.R
RUN Rscript -e 'renv::restore(prompt = FALSE)'

# directly install cmdstan
RUN Rscript -e 'cmdstanr::install_cmdstan(cores = 2)'

COPY . .
RUN mkdir -p data outputs plots

CMD ["bash"]