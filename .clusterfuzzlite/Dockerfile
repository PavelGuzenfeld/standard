FROM gcr.io/oss-fuzz-base/base-builder:ubuntu-24-04@sha256:fafa985698be6b7b6fddc1f260ee37e4f4e99557126db18e91f6096c96cbb177
COPY . $SRC/project
WORKDIR $SRC/project
COPY .clusterfuzzlite/build.sh $SRC/
