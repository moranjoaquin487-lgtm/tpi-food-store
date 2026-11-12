-- C4 · Tablet, después de recargar: la Fugazzeta ya no aparece en el catálogo...
SELECT nombre, printf('%.2f', precio_centavos / 100.0) AS precio, stock_visto
  FROM producto_cache
 WHERE disponible = 1 AND eliminado = 0
 ORDER BY nombre;

-- ...pero su fila queda en producto_cache como lápida, y el borrador que la usa sigue íntegro.
SELECT id, nombre, disponible, eliminado FROM producto_cache WHERE nombre = 'Fugazzeta';
SELECT COUNT(*) AS items_que_apuntan_a_la_fugazzeta
  FROM item_borrador i JOIN producto_cache c ON c.id = i.producto_id
 WHERE c.nombre = 'Fugazzeta';
PRAGMA foreign_key_check;
