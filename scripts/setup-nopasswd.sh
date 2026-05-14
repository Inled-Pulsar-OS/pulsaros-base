#!/bin/bash
# Script para permitir que el usuario actual use pkexec sin contraseña
# ÚTIL SOLO PARA DESARROLLO.

USER_NAME=$(whoami)
RULE_FILE="/etc/polkit-1/rules.d/99-pulsaros-dev.rules"

echo "🔐 Configurando reglas de Polkit para evitar peticiones de contraseña..."

cat <<EOF | pkexec tee "$RULE_FILE"
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        subject.user == "$USER_NAME") {
        return polkit.Result.YES;
    }
});
EOF

if [ $? -eq 0 ]; then
    echo "✅ Regla creada en $RULE_FILE"
    echo "💡 Ahora pkexec no debería pedirte la contraseña en esta máquina."
else
    echo "❌ Error al crear la regla. Asegúrate de poner la contraseña esta última vez."
fi
