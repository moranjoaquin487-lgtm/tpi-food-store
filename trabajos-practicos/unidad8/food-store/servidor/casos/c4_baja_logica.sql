-- C4 · Servidor: baja lógica de la Fugazzeta (R7). La fila no se borra: activo pasa a FALSE.
UPDATE producto
   SET activo = FALSE
 WHERE nombre = 'Fugazzeta';

SELECT nombre, activo FROM producto WHERE nombre = 'Fugazzeta';
