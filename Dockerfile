FROM nfcore/base
LABEL authors="Tobias Neumann" \
      description="Docker image containing all requirements for nf-core/slamseq pipeline"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/nf-core-slamseq-1.0dev/bin:$PATH
