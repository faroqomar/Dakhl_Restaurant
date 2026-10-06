const fs = require('node:fs');
const path = require('node:path');
const model = require('./ui/model.js');
class Storage {
  constructor(directory) { this.directory = directory; this.file = path.join(directory, 'accounts.json'); this.backup = path.join(directory, 'accounts.backup.json'); this.blocked = false; }
  load() {
    fs.mkdirSync(this.directory, { recursive: true, mode: 0o700 });
    try {
      if (!fs.existsSync(this.file)) return model.empty();
      const raw = JSON.parse(fs.readFileSync(this.file, 'utf8')), clean = model.validate(raw);
      // Persist schema upgrades once, with the normal atomic write and a backup of the original file.
      return raw.version !== clean.version ? this.save(clean) : clean;
    }
    catch (error) { this.blocked = true; throw new Error('تعذّر قراءة ملف الحسابات. بياناتك الأصلية محفوظة؛ استورد نسخة احتياطية حتى نكدر نكمل.'); }
  }
  atomic(file, contents) {
    const tmp = `${file}.tmp`; const fd = fs.openSync(tmp, 'w', 0o600);
    try { fs.writeFileSync(fd, contents, 'utf8'); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
    fs.renameSync(tmp, file);
  }
  save(raw, recovery = false) {
    if (this.blocked && !recovery) throw new Error('الحفظ متوقف لحماية ملف الحسابات. استورد نسخة احتياطية أولاً.');
    const clean = model.validate(raw); const contents = JSON.stringify(clean, null, 2);
    if (Buffer.byteLength(contents) > 20 * 1024 * 1024) throw new Error('حجم البيانات أكبر من المسموح.');
    fs.mkdirSync(this.directory, { recursive: true, mode: 0o700 });
    if (fs.existsSync(this.file)) {
      const previous = fs.readFileSync(this.file, 'utf8');
      if (recovery) this.atomic(path.join(this.directory, `accounts-before-import-${Date.now()}.json`), previous);
      else this.atomic(this.backup, previous);
    }
    this.atomic(this.file, contents); this.blocked = false; return clean;
  }
}
module.exports = { Storage };
