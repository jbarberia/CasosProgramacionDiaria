# CasosProgramacionDiaria
Generador de casos de PSSE en función de la programación diaria de CAMMESA.


En caso de que no funcione el modelo en Ipopt se recomienda quitar el escalado con nlp_scaling_method => "none".
De esta manera se bypassea el error de OpenBLAS al correr en una máquina de 64 bits con un entorno de 32 bits.


# TODO

[] Grabar forma de realizar el equivalente en paraguay
[] Eliminar demanda en Chocon 132 kV
[] En los casos, preder toda la red de conexion de los generadores (trafos o colector)
[] Modelar conexion correcta de Agua del Cajon con sus aportes en 500 kV y en 132 kV (Arroyito)
[] Inferir la topologia de Pilar en Centro ya que modifica sensiblemente los resultados en el area centro
[] Las demandas y corredores no observables se deberian agrupar y escalar
[] Prender Yacagua en Bolivia y cerca de eso esta TABATV01.
[] Entre Mercedes 500 kV y Salto Grande se debe estimar cuales son las demandas que van conectadas a cada ET de 500 kV  
[] Normalizar ID de demandas
[] Abrir Guatrache - Puan
