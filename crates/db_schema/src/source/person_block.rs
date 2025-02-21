use crate::newtypes::{PersonBlockId, PersonId};
use serde::{Deserialize, Serialize};

#[cfg(feature = "full")]
use crate::schema::person_block;

#[derive(Clone, PartialEq, Debug, Serialize, Deserialize)]
#[cfg_attr(feature = "full", derive(Queryable, Associations, Identifiable))]
#[cfg_attr(feature = "full", table_name = "person_block")]
pub struct PersonBlock {
  pub id: PersonBlockId,
  pub person_id: PersonId,
  pub target_id: PersonId,
  pub published: chrono::NaiveDateTime,
}

#[cfg_attr(feature = "full", derive(Insertable, AsChangeset))]
#[cfg_attr(feature = "full", table_name = "person_block")]
pub struct PersonBlockForm {
  pub person_id: PersonId,
  pub target_id: PersonId,
}
