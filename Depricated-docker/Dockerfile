FROM 200ms/alpinenet_dev2

RUN dev2_setup.sh add dev2fs update_gnu

RUN apk add rsync util-linux-misc dosfstools e2fsprogs f2fs-tools python3 py3-pip

#COPY files/entry.sh /entry.sh
#RUN chmod +x /entry.sh

COPY files/prepare_image.sh /usr/local/bin/prepare_image.sh
RUN chmod +x /usr/local/bin/prepare_image.sh

CMD [ "/entry.sh" ]
