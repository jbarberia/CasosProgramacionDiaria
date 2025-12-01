# CasosProgramacionDiaria
Generador de casos de PSSE en función de la programación diaria de CAMMESA.


En caso de que no funcione el modelo en Ipopt se recomienda quitar el escalado con nlp_scaling_method => "none".
De esta manera se bypassea el error de OpenBLAS al correr en una máquina de 64 bits con un entorno de 32 bits.


# TODO

[] Grabar forma de realizar el equivalente en paraguay
[] Eliminar demanda en Chocon 132 kV
[] En los casos, preder toda la red de conexion de los generadores (trafos o colector)
