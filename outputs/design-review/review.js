'use strict';
(() => {
  const root = document.createElement('div'); root.id = 'review-root';
  root.innerHTML = `<div id="review-toolbar" aria-label="Design review tools"><small>Sample data · review round 2</small><button id="review-highlight">Highlight & comment</button><button id="review-show">Comments (0)</button><button id="review-export">Export</button></div><div id="review-capture" hidden></div><div id="review-box" hidden></div><section id="review-editor" role="dialog" aria-label="Comment on highlighted area" hidden><h2>What would you like changed?</h2><form id="review-form"><label for="review-text">Describe the layout or design issue</label><textarea id="review-text" placeholder="For example: make this smaller, move this, change the color…" maxlength="4000" required></textarea><div id="review-status" role="status"></div><div class="review-actions"><button type="submit">Save comment</button><button id="review-cancel" type="button">Cancel</button></div></form></section><section id="review-notes" aria-label="Your design comments" hidden><h2>Your comments</h2><ul id="review-list"></ul><div class="review-actions"><button id="review-close">Close</button></div></section>`;
  document.body.append(root);
  const $ = id => document.getElementById(id), capture = $('review-capture'), box = $('review-box'), editor = $('review-editor');
  const revision = 'layout-v2';
  let notes = [], marking = false, start = null, region = null;
  const pageName = () => document.querySelector('#main h1')?.textContent || document.title;
  function showPins() {
    root.querySelectorAll('.review-pin').forEach(el => el.remove());
    for (const [i,n] of notes.entries()) { if (n.page !== pageName() || n.revision !== revision) continue; const pin = document.createElement('div'); pin.className='review-pin'; Object.assign(pin.style,{left:n.region.x+'px',top:n.region.y+'px',width:n.region.width+'px',height:n.region.height+'px'}); const number=document.createElement('span');number.textContent=i+1;pin.append(number);root.append(pin); }
  }
  function update() {
    $('review-show').textContent=`Comments (${notes.length})`;
    $('review-list').replaceChildren();
    for (const [i,n] of notes.entries()) { const li=document.createElement('li'),head=document.createElement('strong'),text=document.createElement('p');head.textContent=`${i+1}. ${n.page} · ${n.target || 'Highlighted area'}`;text.textContent=n.comment;li.append(head,text);$('review-list').append(li); }
    if (!notes.length) {const li=document.createElement('li');li.textContent='Use “Highlight & comment”, then drag over an area to add your first note.';$('review-list').append(li);} showPins();
  }
  function mode(on) {marking=on;capture.hidden=!on;$('review-highlight').classList.toggle('review-mode-on',on);$('review-highlight').textContent=on?'Cancel highlighting':'Highlight & comment';$('review-instruction')?.remove();if(on){const hint=document.createElement('div');hint.id='review-instruction';hint.textContent='Drag over anything you want to change. Press Esc to cancel.';root.append(hint);}}
  function cancel(){editor.hidden=true;box.hidden=true;region=null;mode(false);$('review-highlight').focus();}
  $('review-highlight').onclick=()=>{editor.hidden=true;$('review-notes').hidden=true;box.hidden=true;mode(!marking);};
  capture.addEventListener('pointerdown',e=>{if(e.button!==0)return;start={x:e.clientX,y:e.clientY};capture.setPointerCapture(e.pointerId);box.hidden=false;Object.assign(box.style,{left:(e.clientX+scrollX)+'px',top:(e.clientY+scrollY)+'px',width:'0px',height:'0px'});});
  capture.addEventListener('pointermove',e=>{if(!start)return;Object.assign(box.style,{left:(Math.min(start.x,e.clientX)+scrollX)+'px',top:(Math.min(start.y,e.clientY)+scrollY)+'px',width:Math.abs(e.clientX-start.x)+'px',height:Math.abs(e.clientY-start.y)+'px'});});
  capture.addEventListener('pointerup',e=>{
    if(!start)return;const x=Math.min(start.x,e.clientX),y=Math.min(start.y,e.clientY),w=Math.abs(e.clientX-start.x),h=Math.abs(e.clientY-start.y);capture.hidden=true;
    const target=document.elementFromPoint((start.x+e.clientX)/2,(start.y+e.clientY)/2);
    if(w<5&&h<5&&target){const r=target.getBoundingClientRect();region={x:r.x+scrollX,y:r.y+scrollY,width:r.width,height:r.height};Object.assign(box.style,{left:region.x+'px',top:region.y+'px',width:region.width+'px',height:region.height+'px'});}
    else region={x:x+scrollX,y:y+scrollY,width:Math.max(w,12),height:Math.max(h,12)};
    region.target=(target?.textContent||'').trim().replace(/\s+/g,' ').slice(0,120);start=null;mode(false);editor.hidden=false;$('review-text').value='';$('review-status').textContent='';$('review-text').focus();
  });
  $('review-form').onsubmit=async e=>{e.preventDefault();const comment=$('review-text').value.trim();if(!comment||!region)return;const button=e.target.querySelector('[type=submit]');button.disabled=true;try{const response=await fetch('/review-notes',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({revision,comment,page:pageName(),target:region.target,region:{x:region.x,y:region.y,width:region.width,height:region.height},viewport:{width:innerWidth,height:innerHeight}})});if(!response.ok)throw new Error('Could not save. Please try again.');notes=await response.json();cancel();update();}catch(err){$('review-status').textContent=err.message;}finally{button.disabled=false;}};
  $('review-cancel').onclick=cancel;$('review-close').onclick=()=>$('review-notes').hidden=true;
  $('review-show').onclick=()=>{cancel();$('review-notes').hidden=!$('review-notes').hidden;update();};
  $('review-export').onclick=()=>{const text=notes.map((n,i)=>`${i+1}. ${n.page}\nArea: ${n.target}\nComment: ${n.comment}\n`).join('\n');const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([text||'No comments yet.'],{type:'text/plain;charset=utf-8'}));a.download='Daftar-design-comments.txt';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);};
  document.addEventListener('keydown',e=>{if(e.key==='Escape'&&(marking||!editor.hidden)){e.preventDefault();e.stopImmediatePropagation();cancel();}},true);
  new MutationObserver(()=>showPins()).observe(document.getElementById('main'),{childList:true});
  fetch('/review-notes').then(r=>r.json()).then(data=>{notes=data;update();}).catch(()=>{});
})();
