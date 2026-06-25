FROM node:18-alpine

WORKDIR /usr/src/app
RUN npm install sequelize-cli sequelize pg pg-hstore

COPY migrations/ /migrations/

RUN mkdir -p /app/models && cat > /app/models/base.js << 'EOF'
const { DataTypes: Sq } = require('sequelize');

const DEFAULT_MAPPING_COLUMNS = {
  id: {
    type: Sq.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  createdAt: {
    type: Sq.DATE,
    defaultValue: Sq.NOW,
    name: 'createdAt',
    field: 'created_at',
  },
  deletedAt: {
    type: Sq.DATE,
    name: 'deletedAt',
    field: 'deleted_at',
  },
  updatedAt: {
    type: Sq.DATE,
    name: 'updatedAt',
    field: 'updated_at',
  },
};

const DEFAULT_COLUMNS = {
  ident: {
    type: Sq.UUID,
    unique: false,
    defaultValue: Sq.UUIDV4,
    allowNull: false,
  },
  updatedBy: {
    name: 'updatedBy',
    field: 'updated_by',
    type: Sq.INTEGER,
    references: {
      model: 'users',
      key: 'id',
    },
  },
  ...DEFAULT_MAPPING_COLUMNS,
};

module.exports = { DEFAULT_COLUMNS, DEFAULT_MAPPING_COLUMNS, Sq };
EOF

RUN ln -s /usr/src/app/node_modules /app/node_modules

ENTRYPOINT ["npx", "sequelize-cli", "db:migrate"]