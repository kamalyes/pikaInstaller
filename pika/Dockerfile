FROM python:3.9-slim as builder
WORKDIR /${PK_BASE}
COPY ./requirements.txt ./requirements.txt
RUN python -m venv /${PK_BASE}/venv  \
    && /${PK_BASE}/venv/bin/python -m pip install --upgrade pip \
    && /${PK_BASE}/venv/bin/python -m pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/ \
    && apt update -y \
    && apt upgrade -y \
    && apt install -y tzdata \
    && apt install -y wget \


FROM python:3.9-slim
ENV PYTHONUNBUFFERED=1
WORKDIR /${PK_BASE}
COPY . .
COPY --from=builder /${PK_BASE}/venv/ /${PK_BASE}/venv/
COPY --from=builder /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
COPY --from=builder /${PK_BASE}/wait-for-it.sh /${PK_BASE}/wait-for-it.sh
RUN chmod +x /${PK_BASE}/.env/wait-for-it.sh

EXPOSE 7777

CMD ["/${PK_BASE}/venv/bin/supervisord", "-c", "/${PK_BASE}/supervisor.conf"]
