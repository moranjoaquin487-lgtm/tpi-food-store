-- Escenario 1 · Sesión B: sube el precio de la Muzzarella; sin BEGIN, se confirma solo.
UPDATE producto SET precio = precio + 100 WHERE nombre = 'Muzzarella';
