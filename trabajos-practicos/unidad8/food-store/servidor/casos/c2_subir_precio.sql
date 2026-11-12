-- C2 · Servidor: después de que la tablet armó el borrador, sube el precio de la Muzzarella.
-- Es un cambio del servidor (la fuente de verdad); la tablet no puede hacerlo.
UPDATE producto
   SET precio = 1150.00
 WHERE nombre = 'Muzzarella';

SELECT nombre, precio FROM producto WHERE nombre = 'Muzzarella';
