// Local design review of current UI with illustrative accounts only. No real-account access.
const http = require('node:http'), fs = require('node:fs'), path = require('node:path'), { randomUUID } = require('node:crypto');
const { previewFixture }=require('./preview-fixture.cjs');
const M=require('../app/ui/model.js');
const root=path.resolve(__dirname,'..'), ui=path.join(root,'app/ui'), review=path.join(root,'outputs/design-review'), notesFile=path.join(review,'comments.json');
fs.mkdirSync(review,{recursive:true});
const uiFiles=new Set(['index.html','styles.css','commerce.css','ux.css','ux.js','model.js','numbers.js','suppliers.js','commerce.js','renderer.js']);
const reviewFiles=new Set(['bridge.js','review.js','review.css']);
function readNotes(){return fs.existsSync(notesFile)?JSON.parse(fs.readFileSync(notesFile,'utf8')):[];}
function json(res,code,data){res.writeHead(code,{'Content-Type':'application/json;charset=utf-8','Cache-Control':'no-store'});res.end(JSON.stringify(data));}
const server=http.createServer(async(req,res)=>{
 try {
  const url=new URL(req.url,'http://127.0.0.1');
  if(url.pathname==='/review-notes') {
   if(req.method==='GET')return json(res,200,readNotes());
   if(req.method!=='POST')return json(res,405,{error:'Method not allowed'});
   const origin=req.headers.origin;if(origin&&origin!==`http://${req.headers.host}`)return json(res,403,{error:'Origin not allowed'});
   let body='';for await(const chunk of req){body+=chunk;if(Buffer.byteLength(body)>20000)return json(res,413,{error:'Too large'});}
   const note=JSON.parse(body);
   if(typeof note.comment!=='string'||!note.comment.trim()||note.comment.length>4000||typeof note.page!=='string'||note.page.length>300||typeof note.target!=='string'||note.target.length>120||!note.region||!['x','y','width','height'].every(k=>Number.isFinite(note.region[k])&&note.region[k]>=0&&note.region[k]<100000))return json(res,400,{error:'Invalid comment'});
   const notes=readNotes();notes.push({id:randomUUID(),createdAt:new Date().toISOString(),comment:note.comment.trim(),page:note.page,target:note.target,region:note.region,viewport:note.viewport,revision:typeof note.revision==='string'?note.revision.slice(0,40):'layout-v1'});
   fs.writeFileSync(notesFile+'.tmp',JSON.stringify(notes,null,2),{mode:0o600});fs.renameSync(notesFile+'.tmp',notesFile);return json(res,200,notes);
  }
  if(req.method!=='GET')return json(res,405,{error:'Method not allowed'});
  if(url.pathname==='/preview-fixture.js'){res.writeHead(200,{'Content-Type':'text/javascript;charset=utf-8'});return res.end('window.previewFixture='+JSON.stringify(previewFixture())+';');}
  const thumb=/^\/photos\/thumbs\/([a-z-]+)-(240|480)\.webp$/.exec(url.pathname);
  if(thumb && M.productPhotos.includes(thumb[1])){res.writeHead(200,{'Content-Type':'image/webp'});return res.end(fs.readFileSync(path.join(ui,'photos','thumbs',thumb[1]+'-'+thumb[2]+'.webp')));}
  const photo = /^\/photos\/([a-z-]+)\.png$/.exec(url.pathname);
  if (photo && M.productPhotos.includes(photo[1])) { res.writeHead(200,{'Content-Type':'image/png','Cache-Control':'no-store'}); return res.end(fs.readFileSync(path.join(ui,'photos',photo[1]+'.png'))); }
  const filename=url.pathname==='/'?'index.html':url.pathname.slice(1);if(!uiFiles.has(filename)&&!reviewFiles.has(filename))return json(res,404,{error:'Not found'});
  let data=fs.readFileSync(path.join(uiFiles.has(filename)?ui:review,filename));
  if(filename==='index.html')data=data.toString().replace("connect-src 'none'","connect-src 'self'").replace('<script defer src="renderer.js"></script>','<script defer src="preview-fixture.js"></script><script defer src="bridge.js"></script><script defer src="renderer.js"></script>');
  res.writeHead(200,{'Content-Type':filename.endsWith('.css')?'text/css;charset=utf-8':filename.endsWith('.js')?'text/javascript;charset=utf-8':'text/html;charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(data);
 }catch(e){json(res,500,{error:'Preview request failed'});}
});
const port=Number(process.env.DAFTAR_PREVIEW_PORT||4317);server.listen(port,'127.0.0.1',()=>console.log('Daftar design review: http://127.0.0.1:'+port));
