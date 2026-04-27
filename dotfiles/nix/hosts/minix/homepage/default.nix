{
  pkgs,
  lib,
  title,
  sections,
  glancesPort,
}:
let
  renderItem = i: ''<a class="row" href="${i.url}">${i.name}</a>'';
  renderSection =
    s:
    ''
      <section><div class="label">${s.label}</div>
    ''
    + lib.concatMapStringsSep "\n" renderItem s.items
    + ''
      </section>
    '';
  indexHtml = pkgs.writeText "index.html" ''
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>${title}</title>
    <style>${builtins.readFile ./style.css}</style>
    </head>
    <body>
    <div class="host">${title}</div>
    ${lib.concatMapStringsSep "\n" renderSection sections}
    <section><div class="label">system</div>
      <div class="stats">
        <span class="k">cpu</span><span class="v dim" id="cpu">-</span>
        <span class="k">mem</span><span class="v dim" id="mem">-</span>
        <span class="k">swap</span><span class="v dim" id="swap">-</span>
      </div>
    </section>
    <script>
    async function refresh(){
      try{
        const r=await fetch(`http://''${location.hostname}:${toString glancesPort}/api/4/all`,{cache:'no-store'});
        if(!r.ok)return;
        const d=await r.json();
        const set=(id,v)=>{const e=document.getElementById(id);e.textContent=v;e.classList.remove('dim');};
        set('cpu',Math.round(d.cpu.total)+'%');
        set('mem',Math.round(d.mem.percent)+'%');
        set('swap',Math.round(d.memswap.percent)+'%');
      }catch(e){}
    }
    refresh();
    setInterval(refresh,5000);
    </script>
    </body>
    </html>
  '';
in
pkgs.runCommand "minix-homepage" { } ''
  mkdir -p $out
  cp ${indexHtml} $out/index.html
''
