# Sandbox for the Open AG Patcher: the patcher code is copied INTO the image
# at build time (pinned local source), never downloaded at runtime.
# Network is intentionally absent at runtime (the host controls it per-run).
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/home/aguser/patcher-src/source \
    HOME=/home/aguser

# uid 1000 == host user (aaa) so bind-mounted targets stay writable
RUN useradd -m -u 1000 aguser

WORKDIR /home/aguser

# Pinned patcher source (host dir: sources/patcher/)
COPY sources/patcher /home/aguser/patcher-src

# Non-interactive driver + entrypoint
COPY build/driver.py /home/aguser/driver.py
COPY build/entrypoint.sh /home/aguser/entrypoint.sh

# Only dependency the patcher needs at runtime: `packaging`
RUN pip install --no-cache-dir packaging \
    && chmod +x /home/aguser/entrypoint.sh

USER aguser
ENTRYPOINT ["/home/aguser/entrypoint.sh"]