-- Repas & Courses : menus, listes et recettes partagés en ligne.
-- Une ligne par document : app/config, weeks/<vendredi>, recipes/<id>, checks/<vendredi>.
-- Réexécutable sans erreur (on peut aussi la coller dans le SQL Editor).

create table if not exists public.repas_docs (
  path text primary key,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.repas_docs enable row level security;

-- Seuls les comptes connectés (Vincent, Agnès) lisent et écrivent. Les visiteurs anonymes ne voient rien.
drop policy if exists "repas: comptes connectés" on public.repas_docs;
create policy "repas: comptes connectés" on public.repas_docs
  for all to authenticated using (true) with check (true);

revoke all on public.repas_docs from anon;
grant select, insert, update, delete on public.repas_docs to authenticated;

-- Cocher un article de courses sans écraser ce que l'autre coche en même temps.
create or replace function public.repas_merge_items(p_path text, p_items jsonb)
returns void
language sql
security invoker
set search_path = public
as $$
  insert into repas_docs (path, data, updated_at)
  values (p_path, jsonb_build_object('items', p_items), now())
  on conflict (path) do update
    set data = jsonb_set(repas_docs.data, '{items}', coalesce(repas_docs.data->'items', '{}'::jsonb) || excluded.data->'items'),
        updated_at = now();
$$;

revoke execute on function public.repas_merge_items(text, jsonb) from public, anon;
grant execute on function public.repas_merge_items(text, jsonb) to authenticated;

-- Mises à jour en direct entre les téléphones.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'repas_docs'
  ) then
    alter publication supabase_realtime add table public.repas_docs;
  end if;
end $$;
