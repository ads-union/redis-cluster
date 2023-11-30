#FROM redis:6.2-alpine
FROM redis:7.2.2-alpine
EXPOSE 16379
COPY --chmod=777 ./startup.sh /usr/local/bin/startup.sh
CMD [ "startup.sh" ]
