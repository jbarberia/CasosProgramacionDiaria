"""
Funciones para descargar la programacion diaria
"""
const NEMO = "PROGRAMACION_DIARIA"
const BASEURL = "https://api.cammesa.com/pub-svc"


"""
    get_doc_id(fecha::DateTime)

Consulta el servicio de CAMMESA para obtener la metadata del archivo
"""
function get_doc_id(fecha::DateTime)
    params = Dict(
        "fechadesde" => Dates.format(fecha, dateformat"yyyy-mm-ddTHH:MM:SS"),
        "fechahasta" => Dates.format(fecha, dateformat"yyyy-mm-ddTHH:MM:SS"),
        "nemo" => NEMO
    )
    r = HTTP.get("$BASEURL/public/findDocumentosByNemoRango"; query=params)
    if r.status == 200
        return JSON3.read(String(r.body))
    else
        error("No se pudo descargar datos de ID")
    end
end


"""
    download_zip_file(datos_archivo)

Descarga el archivo ZIP dado por los metadatos.
"""
function download_zip_file(datos_archivo)
    params = Dict(
        "attachmentId" => datos_archivo["adjuntos"][1]["id"],
        "docId" => datos_archivo["id"],
        "nemo" => NEMO
    )
    r = HTTP.get("$BASEURL/public/findAttachmentByNemoId"; query=params)

    zipfilename = datos_archivo["adjuntos"][1]["nombre"]
    if r.status == 200
        Base.open(zipfilename, "w") do io
            write(io, r.body)
        end
        return abspath(zipfilename)
    else
        error("No se pudo descargar el archivo ZIP")
    end
end


"""
    download_programacion(fecha::DateTime)

Descarga el ZIP correspondiente a la fecha indicada.
"""
function download_programacion(fecha::DateTime)
    archivo = "PD" * Dates.format(fecha, "yymmdd") * ".zip"
    response = get_doc_id(fecha)
    datos_archivo = filter(d -> d["adjuntos"][1][:id] == archivo, response)[1]
    return download_zip_file(datos_archivo)
end


"""
    parse_programacion(zipfile::AbstractString)

Lee todos los CSV dentro del ZIP y los guarda como DataFrames.
"""
function parse_programacion(zipfile::AbstractString)
    dataframes = Dict{String,DataFrame}()

    z = ZipFile.Reader(zipfile)
    for f in z.files
        if endswith(f.name, ".csv")
            df = CSV.read(f, DataFrame)
            dataframes[uppercase(replace(f.name, ".csv" => ""))] = df
        end
    end
    close(z)
    return dataframes
end

"""
    get_programacion(fecha::DateTime)

Devuelve la programacion diaria de CAMMESA con la fecha dada
"""
function get_programacion_diaria(fecha::DateTime)
    filename = download_programacion(fecha)
    data = parse_programacion(filename)    
    # rm(filename)
    return data
end
