# 📋 Application Django de Gestion des Signatures de Documents

Une application web complète pour gérer les signatures numériques de documents avec suivi d'état, vérification et archivage.

## 🎯 Fonctionnalités Principales

### ✅ Gestion des Utilisateurs
- Inscription et authentification sécurisée
- Gestion des profils utilisateur personnalisés
- Rôles (propriétaire de document, signataire)
- Avatar et signature numérique personnalisée
- Informations professionnelles

### ✅ Gestion des Documents
- Téléchargement et création de documents
- Support multi-signataires
- Ordre de signature configurable (parallèle ou séquentiel)
- Dates d'expiration
- Intégrité des fichiers (SHA256)
- Archivage automatique

### ✅ Signature de Documents
- Interface de signature en ligne
- Pad de signature numérique
- Signature par image
- Horodatage automatique
- Traçabilité complète (IP, User-Agent)

### ✅ Suivi et Vérification
- Statut de signature en temps réel
- Barre de progression de signature
- Journaux d'audit complets
- Vérification d'intégrité des fichiers
- Historique détaillé des actions

### ✅ Archivage et Conservation
- Conservation sécurisée des documents
- Stockage des métadonnées de signature
- Recherche et filtrage avancés
- Téléchargement sécurisé
- Exportation des métadonnées

## 📁 Structure du Projet

```
signature_project/
├── signature_project/          # Dossier du projet Django
│   ├── __init__.py
│   ├── settings.py            # Configuration Django
│   ├── urls.py                # URLs principales
│   └── wsgi.py                # Configuration WSGI
│
├── documents/                 # Application Django
│   ├── __init__.py
│   ├── models.py              # Modèles de données
│   ├── views.py               # Logique métier
│   ├── urls.py                # URLs de l'app
│   ├── admin.py               # Interface admin
│   ├── apps.py                # Configuration app
│   └── migrations/            # Migrations BDD
│
├── templates/                 # Templates HTML
│   ├── base.html              # Template de base
│   ├── dashboard.html         # Tableau de bord
│   ├── auth/                  # Templates auth
│   ├── documents/             # Templates documents
│   └── users/                 # Templates utilisateurs
│
├── static/                    # Fichiers statiques
├── media/                     # Fichiers uploadés
├── manage.py                  # Gestion Django
├── requirements.txt           # Dépendances Python
└── README.md                  # Ce fichier
```

## 🗄️ Modèles de Données

### Document
```
- title (CharField): Titre du document
- description (TextField): Description
- file (FileField): Fichier à signer
- owner (ForeignKey): Propriétaire
- status (CharField): État (draft, pending, partially_signed, fully_signed, archived)
- file_hash (CharField): SHA256 du fichier
- file_size (BigIntegerField): Taille du fichier
- due_date (DateTimeField): Date limite
- created_at, updated_at (DateTimeField): Timestamps
```

### DocumentSigner
```
- document (ForeignKey): Document à signer
- user (ForeignKey): Signataire
- signature_status (CharField): État (pending, viewed, signed, rejected, expired)
- order (PositiveIntegerField): Ordre de signature
- signature_data (TextField): Données de signature (Base64)
- digital_signature (CharField): Hash SHA256 de la signature
- signature_date (DateTimeField): Date de signature
- ip_address (GenericIPAddressField): IP du signataire
- user_agent (TextField): Info du navigateur
- rejection_reason (TextField): Raison du rejet
- created_at, updated_at (DateTimeField): Timestamps
```

### SignatureLog
```
- document (ForeignKey): Document concerné
- action (CharField): Type d'action
- user (ForeignKey): Utilisateur
- details (TextField): Détails
- ip_address (GenericIPAddressField): IP
- timestamp (DateTimeField): Quand
```

### UserProfile
```
- user (OneToOneField): Utilisateur
- phone (CharField): Téléphone
- organization (CharField): Organisation
- job_title (CharField): Fonction
- avatar (ImageField): Photo de profil
- signature_image (ImageField): Signature numérique
- bio (TextField): Biographie
- created_at, updated_at (DateTimeField): Timestamps
```

## 🚀 Installation Rapide

### 1. Prérequis
- Python 3.8+
- pip
- virtualenv (recommandé)

### 2. Cloner le projet
```bash
cd signature_project
```

### 3. Créer un environnement virtuel
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
# ou
venv\Scripts\activate  # Windows
```

### 4. Installer les dépendances
```bash
pip install -r requirements.txt
```

### 5. Configurer la base de données
```bash
# Créer les tables
python manage.py makemigrations
python manage.py migrate

# Créer un superutilisateur
python manage.py createsuperuser
```

### 6. Lancer le serveur
```bash
python manage.py runserver
```

L'application est accessible à `http://localhost:8000`

## 👥 Guide d'Utilisation

### Pour les Propriétaires de Documents

#### 1. Créer et télécharger un document
- Aller à "Télécharger" dans la navigation
- Remplir les informations (titre, description, fichier, date limite optionnelle)
- Le document est en statut "Brouillon"

#### 2. Ajouter des signataires
- Ouvrir le document créé
- Cliquer "Ajouter les signataires"
- Sélectionner les utilisateurs
- Définir l'ordre de signature (0 = parallèle, 1,2,3... = séquentiel)
- Le statut passe à "En attente de signature"

#### 3. Suivre l'état des signatures
- Tableau de bord: voir la progression globale
- Détails du document: voir l'état de chaque signataire
- Historique: consulter tous les événements

#### 4. Vérifier les signatures
- Cliquer sur "Vérifier" pour une signature
- Voir les métadonnées (date, IP, User-Agent)
- Valider l'authenticité

#### 5. Archiver les documents
- Une fois signé: cliquer "Archiver"
- Conservation permanente avec métadonnées

### Pour les Signataires

#### 1. Consulter les tâches de signature
- Tableau de bord: voir "Mes tâches de signature"
- Chaque tâche affiche le document et son propriétaire

#### 2. Signer un document
- Cliquer sur "Signer"
- Lire le document (consultable en ligne)
- Signer avec le pad ou uploader une image
- Confirmer la signature
- Vous êtes automatiquement noté comme signataire

#### 3. Rejeter une signature (optionnel)
- Cliquer sur "Rejeter"
- Fournir la raison
- Envoyer

#### 4. Voir l'historique
- Tableau de bord: voir toutes vos signatures
- Profil: statistiques détaillées

## 🔒 Sécurité

- ✅ Authentification Django (PBKDF2)
- ✅ Permissions basées sur les rôles
- ✅ Vérification d'intégrité (SHA256)
- ✅ Horodatage et traçabilité complète
- ✅ Protection CSRF
- ✅ CORS configuré
- ✅ Validation des fichiers

## 📊 API JSON mobile

Vues Django classiques renvoyant du JSON (pas DRF), montées sous `/api/`.
L'authentification est le cookie de session ouvert par la connexion passkey
(`/chiffrement_app/login/verify/`).

### Endpoints

```
GET  /api/me/                                   # Identité + état de la clé RSA
GET  /api/keys/                                 # Clé publique active
POST /api/keys/                                 # Enregistrer une clé publique
GET  /api/documents/                            # Documents affectés / possédés
GET  /api/documents/<id>/                       # Détail + signataires + journal
GET  /api/documents/<id>/file/                  # Octets exacts à hacher
GET  /api/documents/<id>/verify/                # Vérification globale (§2.5)
POST /api/documents/<id>/sign/challenge/        # Défi passkey à usage unique
POST /api/documents/<id>/sign/                  # Déposer la signature RSA
```

Toute erreur attendue arrive sous la forme
`{"error": "<code>", "detail": "<message>"}` : `authentication_required` (401),
`not_a_signer` (403), `already_signed` (409), `hash_mismatch`,
`challenge_expired`, `invalid_signature` (422)…

### Déroulé d'une signature

```
1. GET  /api/documents/12/file/          → le téléphone calcule SHA-256 lui-même
2. POST /api/documents/12/sign/challenge/  {"documentHash": "<hex>"}
                                          → refusé si l'empreinte a changé
                                          → renvoie un défi WebAuthn à usage unique
3. L'utilisateur confirme avec sa passkey (biométrie / PIN)
4. Le téléphone signe l'empreinte avec sa clé privée RSA
5. POST /api/documents/12/sign/  {"challengeId", "credential", "signature"}
                                          → le serveur vérifie l'assertion,
                                            consomme le défi, puis vérifie la
                                            signature RSA
```

Le défi est lié au triplet (utilisateur, document, empreinte) et consommé même
en cas d'échec : une session ouverte ne suffit jamais à signer (§2.1).

### Cryptographie

| Élément | Choix |
|---------|-------|
| Empreinte | SHA-256, calculée sur le téléphone à partir des octets téléchargés |
| Signature | RSA-2048, PKCS#1 v1.5 (`RSASSA-PKCS1-v1_5-SHA256`) |
| Vérification serveur | `cryptography`, `PKCS1v15()` + `Prehashed(SHA256())` |
| Clé publique | PEM enregistré dans `SigningKey` (SPKI ou PKCS#1 acceptés) |
| Empreinte de clé | SHA-256 du DER SPKI, donc stable quel que soit l'encodage |

La signature porte sur l'empreinte, pas sur le fichier : le client signe les
octets avec `SHA-256/RSA`, ce qui produit exactement le `DigestInfo(SHA-256, H)`
que le serveur vérifie en mode `Prehashed`.

### Clé privée

Deux implémentations derrière l'interface `SigningService`, choisies au
démarrage par `resolveSigningService()` :

| Backend | Où vit la clé privée | Utilisé quand |
|---------|----------------------|---------------|
| `KeystoreSigningService` | Android Keystore, **non exportable** | Android (par défaut) |
| `LocalSigningService` | PEM dans `flutter_secure_storage` | Ailleurs (repli) |

Sur Android la paire est générée par le Keystore lui-même
(`SigningKeyHandler.kt`, `KeyGenParameterSpec` / `PURPOSE_SIGN` /
`SIGNATURE_PADDING_RSA_PKCS1`) : aucun code, pas même celui de l'application,
ne peut relire la clé privée. La signature est produite par
`Signature.getInstance("SHA256withRSA")`, ce qui donne exactement le PKCS#1
v1.5 que Django vérifie.

`setUserAuthenticationRequired(true)` n'est volontairement pas activé : la
passkey exigée juste avant chaque signature prouve déjà la présence de
l'utilisateur, et un second prompt biométrique n'ajouterait que de la
friction. La clé reste non exportable dans les deux cas.

La clé privée n'est jamais transmise : `POST /api/keys/` refuse explicitement
tout PEM contenant `PRIVATE KEY`, et des tests le vérifient des deux côtés.

### Versions (§2.5)

Le fichier n'appartient pas au document mais à une `DocumentVersion` :

```
Document          titre, propriétaire, statut, signataires
  └── versions    v1, v2, v3…  (fichier + SHA-256 + qui l'a déposée)
        └── signatures        rattachées à la version qu'elles couvrent
```

Déposer un nouveau contenu (`POST /document/<id>/version/`) crée une version,
remet tous les signataires en attente et fait retomber le document en
`pending`. Rien n'est écrasé : l'ancienne version et ses signatures restent en
base, toujours vérifiables pour les octets qu'elles couvraient — elles ne
comptent simplement plus pour la version courante.

`Document.file`, `.file_hash`, `.file_size` et `.mime_type` restent lisibles :
ce sont des propriétés qui délèguent à la version courante. L'empreinte est
calculée une seule fois, à la création de la version ; l'ancien
`Document.save()` relisait tout le fichier à chaque sauvegarde, y compris pour
un simple changement de statut.

### Vérification globale (§2.5)

`chiffrement_app.services` est la source unique de vérité, partagée par l'API
mobile et les vues web :

- `recompute_document_status(document)` dérive l'état
  (`pending` → `partially_signed` → `fully_signed`) des **signatures
  réellement enregistrées**, jamais d'un champ de statut posé à la main ;
- `verify_document(document)` renvoie les quatre conditions séparément, pour
  que « pas encore signé » (`incomplete`) et « signature cassée » (`invalid`)
  ne se confondent jamais.

> La signature depuis un navigateur a été retirée : elle basculait un champ de
> statut sans aucune cryptographie derrière, ce qui faisait diverger l'état du
> document et son rapport de vérification. `sign_document` renvoie désormais
> vers l'application mobile.

### Périmètre de l'application web

« Les documents signés et les signatures électroniques doivent être visibles
uniquement dans l'application mobile. »

| L'application web | L'application mobile |
|-------------------|----------------------|
| Créer et gérer les comptes | S'authentifier par passkey |
| Déposer un document, déposer une version | Consulter les documents affectés |
| Affecter des signataires | Signer (passkey + clé privée RSA) |
| Suivre l'état, consulter le journal | Voir les autres signatures |
| Lancer la vérification et lire le verdict | Vérifier document et signatures |
| — | **Seule à accéder au fichier et aux valeurs de signature** |

Concrètement : `MEDIA_URL` n'est volontairement pas branché sur `urlpatterns`,
le fichier n'est servi que par `GET /api/documents/<id>/file/` après
vérification du droit d'accès, et aucun gabarit web ne rend
`Signature.signature_value`. Des tests le vérifient
(`chiffrement_app/tests/test_web_scope.py`).

Un administrateur peut créer un compte signataire
(`/chiffrement_app/users/create/`) ; la fiche utilisateur montre ses passkeys
et l'empreinte de ses clés publiques, jamais la partie privée.

## 🛠️ Configuration Avancée

### Variables d'environnement

Créer un fichier `.env`:

```env
DEBUG=False
SECRET_KEY=your-very-secret-key-here
ALLOWED_HOSTS=example.com,www.example.com
DATABASE_URL=postgresql://user:password@localhost/dbname
```

### Utiliser PostgreSQL

Modifier `settings.py`:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'signature_db',
        'USER': 'postgres',
        'PASSWORD': 'password',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}
```

### Configurer le courrier électronique

```python
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST_USER = 'your-email@gmail.com'
EMAIL_HOST_PASSWORD = 'your-password'
DEFAULT_FROM_EMAIL = 'noreply@example.com'
```

## 📦 Déploiement

### Avec Gunicorn

```bash
gunicorn signature_project.wsgi --bind 0.0.0.0:8000 --workers 4
```

### Avec Docker

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN python manage.py collectstatic --noinput

EXPOSE 8000
CMD ["gunicorn", "signature_project.wsgi", "--bind", "0.0.0.0:8000"]
```

### Avec Docker Compose

```yaml
version: '3.8'
services:
  web:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DEBUG=False
      - DATABASE_URL=postgresql://user:password@db/signdb
    depends_on:
      - db
    volumes:
      - ./media:/app/media
      - ./staticfiles:/app/staticfiles

  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=signdb
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

## 🧪 Commandes Utiles

```bash
# Créer les migrations
python manage.py makemigrations

# Appliquer les migrations
python manage.py migrate

# Créer un utilisateur admin
python manage.py createsuperuser

# Accéder au shell Django
python manage.py shell

# Collecter les fichiers statiques
python manage.py collectstatic

# Lancer les tests
python manage.py test

# Afficher les URLs
python manage.py show_urls
```

## 🐛 Dépannage

### Erreur: "No module named 'django'"
```bash
pip install -r requirements.txt
```

### Erreur: "Table does not exist"
```bash
python manage.py migrate
```

### Erreur: "Fichiers statiques non trouvés"
```bash
python manage.py collectstatic --noinput
```

### Erreur de permission lors du téléchargement
- Vérifier les permissions du dossier `media/`
- Linux: `chmod -R 755 media/`

## 📈 Statuts Détaillés

### Statuts de Document
| Statut | Description |
|--------|-------------|
| **Brouillon** | Créé, pas encore envoyé pour signature |
| **En attente** | Signataires ajoutés, en cours de signature |
| **Partiellement signé** | Certains signataires ont signé |
| **Complètement signé** | Tous les signataires ont signé ✓ |
| **Archivé** | Conservé, pas de modification possible |

### Statuts de Signataire
| Statut | Description |
|--------|-------------|
| **En attente** | Signataire n'a pas encore consulté |
| **Consulté** | Document consulté, pas encore signé |
| **Signé** | Document signé ✓ |
| **Refusé** | Signature refusée avec raison |
| **Expiré** | Date limite dépassée ⏰ |

## 📝 Événements Auditables

Chaque action est enregistrée:
- Document créé
- Signataire ajouté/supprimé
- Document consulté
- Document signé
- Signature refusée
- Document téléchargé
- Document archivé

## 🤝 Support et Contribution

Pour les questions:
1. Consulter la documentation
2. Vérifier les logs: `python manage.py shell`
3. Interface admin: `http://localhost:8000/admin/`

## 📄 Licence

MIT License - Libre d'utilisation

## 👨‍💻 Auteur

Application Django créée pour la gestion sécurisée des signatures de documents.

---

**Version**: 1.0.0  
**Dernière mise à jour**: 2024  
**Status**: Production Ready ✅