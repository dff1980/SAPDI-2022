```bash
zypper in -y mysql
zypper in -y nginx
zypper in -y rmt-server yast2-rmt

yast rmt

rmt-cli sync

cat > rmt-products-add.sh <<EOF
products=$(rmt-cli products list --all | grep "15 SP3" | grep x86_64 | grep -v 'Business Critical Linux\|for SAP Applications' )
for product in "SUSE Linux Enterprise Server" "Basesystem Module" "Containers Module" "Server Applications Module" "Web and Scripting Module"
 do
  rmt-cli products enable $(echo "$products" | grep "$product" | sed "s/^|\s\+\([0-9]*\)\s\+|.*/\1/");
 done
EOF

sh rmt-products-add.sh

rmt-cli mirror
```