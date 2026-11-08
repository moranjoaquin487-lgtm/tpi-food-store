-- Escenario 2 · Sesión B: registra un pedido nuevo de Ana Gómez; sin BEGIN, se confirma solo.
INSERT INTO pedido (forma_pago, cliente_id)
SELECT 'EFECTIVO', id FROM cliente WHERE email = 'ana.gomez@mail.com';
