# DrNote

**Note: This repository page will be updated upon acceptance.**

The DrNote annotation tool features a simple yet effective annotation tool for various purposes.  

The annotation method is based on the [Opentapioca](https://arxiv.org/abs/1904.09131) [(GitHub)](https://github.com/wetneb/opentapioca) codebase to provide a named entity linking functionality on unstructured text data.

The project leverages the data from Wikidata and Wikipedia without the requirement of any commercial components.  

The annotation service provides a web-based UI as well as an API-based access.  

The processing of PDF files is supported. Linked entities can be injected as hyperlinks into the uploaded PDF file.  

Different languages (de, en, es etc.) are supported.

## How to Use
Steps to automatically build the OpenTapioca data setup pipeline and spawn the annotation service.  

Prestep: Setup the configuration:
  * Modify the file `./cfg/opentapioca_profile.json`.
  * Modify the file `./cfg/load_config.json`.  
    **Note:** The language code should match  the entry in `./cfg/opentapioca_profile.json`.

Steps:
1. Check dependencies:
   * Run `./01_checkDependencies.sh`

2. Generate the NIF file:
   * Run `./02_loadNIFFile.sh`

3. Generate the OpenTapioca data:
   * Run `./03_processForOpenTapioca.sh`

4. Spawn the MISIT annotation service:
   * Run `./04_start_annotation_service.sh`

The annotation service should be available at:  
`https://<DOCKER_HOST>/`

Our demo instance is available at:  
[https://textmining.misit-augsburg.de](https://textmining.misit-augsburg.de)  
*Note:* Upload of large PDF files is not supported. Uploaded data is discarded after processing.  


## Referenced Repositories
 - [Annotation Service](https://git.rz.uni-augsburg.de/freijoha/annotation-service) provides the Webservice for a given PDF/Text.
 - [Annotation NIF Generation](https://git.rz.uni-augsburg.de/freijoha/annotation-nif-generation) extracts a NIF-compatible file from Wikipedia.
 - [OpenTapioca Wrapper](https://git.rz.uni-augsburg.de/freijoha/opentapioca) wraps the OpenTapioca build/preprocessing/training pipeline (including Solr). 
 - [PDF Processing Library](https://git.rz.uni-augsburg.de/freijoha/pdf-link2doc) implements the PDF Text extraction and link editing functionality.

 Not required for smaller queries:
 - [WikiData Query Instance Wrapper](https://git.rz.uni-augsburg.de/freijoha/wikidata-query-service)