FROM alpine:3.8

RUN apk add jq curl

COPY ./init.sh /vault/

CMD /vault/init.sh
